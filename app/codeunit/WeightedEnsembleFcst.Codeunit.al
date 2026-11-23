/// <summary>
/// Combines all single methods, weighting each one for every step by how often it guessed the direction on the latest candles:
/// weight = smoothed hit rate - 50%. Methods at or below 50% get no weight; if no method has a positive weight, the forecast is flat (no signal).
/// </summary>
codeunit 50124 "SMA Weighted Ensemble Fcst" implements "SMA IForecast Method"
{
    Access = Internal;

    var
        ForecastEngine: Codeunit "SMA Forecast Engine";
        ForecastMath: Codeunit "SMA Forecast Math";

    procedure Forecast(var ForecastContext: Codeunit "SMA Forecast Context"; Steps: Integer; var Points: List of [Decimal]; var Sigmas: List of [Decimal])
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        Components: List of [Integer];
        ComponentPoints: Dictionary of [Integer, List of [Decimal]];
        ComponentSigmas: Dictionary of [Integer, List of [Decimal]];
        MethodPoints: List of [Decimal];
        MethodSigmas: List of [Decimal];
        Hits: array[16, 240] of Integer;
        Samples: array[16, 240] of Integer;
        BaseClose: Decimal;
        Weight: Decimal;
        SumWeight: Decimal;
        SumMove: Decimal;
        SumWeightedSigma: Decimal;
        SumSigma: Decimal;
        Ordinal: Integer;
        SavedPosition: Integer;
        FromPosition: Integer;
        EvaluatedSteps: Integer;
        StepIndex: Integer;
        PredictedDir: Integer;
        ActualDir: Integer;
        ValidCount: Integer;
        m: Integer;
        q: Integer;
        s: Integer;
    begin
        Clear(Points);
        Clear(Sigmas);
        ForecastContext.GetSetup(RateAnalyzerSetup);
        SavedPosition := ForecastContext.Position();
        if SavedPosition < 2 then
            exit;

        foreach Ordinal in Enum::"SMA Forecast Method".Ordinals() do
            if IsComponent(Ordinal) and (Components.Count() < 16) then
                Components.Add(Ordinal);

        // current forecasts of the components
        for m := 1 to Components.Count() do begin
            ForecastEngine.GetForecast(ForecastContext, Enum::"SMA Forecast Method".FromInteger(Components.Get(m)), Steps, MethodPoints, MethodSigmas);
            if MethodPoints.Count() >= Steps then begin
                ComponentPoints.Add(m, MethodPoints);
                ComponentSigmas.Add(m, MethodSigmas);
            end;
        end;
        if ComponentPoints.Count() = 0 then
            exit;

        // hit rate of every component per step on the latest candles (only outcomes known at the current position)
        EvaluatedSteps := Steps;
        if EvaluatedSteps > 240 then
            EvaluatedSteps := 240;
        FromPosition := SavedPosition - RateAnalyzerSetup.GetEnsembleWeightCandles();
        if FromPosition < ForecastContext.Lookback() then
            FromPosition := ForecastContext.Lookback();
        for q := FromPosition to SavedPosition - 1 do begin
            ForecastContext.SetPosition(q);
            BaseClose := ForecastContext.CloseAt(q);
            for m := 1 to Components.Count() do
                if ComponentPoints.ContainsKey(m) then begin
                    ForecastEngine.GetForecast(ForecastContext, Enum::"SMA Forecast Method".FromInteger(Components.Get(m)), Steps, MethodPoints, MethodSigmas);
                    if MethodPoints.Count() >= Steps then
                        for s := 1 to EvaluatedSteps do
                            if (q + s <= SavedPosition) and ForecastContext.IsContinuous(q, q + s) then begin
                                PredictedDir := ForecastMath.Sign(MethodPoints.Get(s) - BaseClose);
                                ActualDir := ForecastMath.Sign(ForecastContext.CloseAt(q + s) - BaseClose);
                                if (PredictedDir <> 0) and (ActualDir <> 0) then begin
                                    Samples[m, s] += 1;
                                    if PredictedDir = ActualDir then
                                        Hits[m, s] += 1;
                                end;
                            end;
                end;
        end;
        ForecastContext.SetPosition(SavedPosition);

        BaseClose := ForecastContext.CloseAt(SavedPosition);
        for s := 1 to Steps do begin
            StepIndex := s;
            if StepIndex > EvaluatedSteps then
                StepIndex := EvaluatedSteps;
            SumWeight := 0;
            SumMove := 0;
            SumWeightedSigma := 0;
            SumSigma := 0;
            ValidCount := 0;
            for m := 1 to Components.Count() do
                if ComponentPoints.Get(m, MethodPoints) then begin
                    ComponentSigmas.Get(m, MethodSigmas);
                    // Laplace smoothing keeps methods with few samples close to 50%
                    Weight := (Hits[m, StepIndex] + 1) / (Samples[m, StepIndex] + 2) - 0.5;
                    if Weight > 0 then begin
                        SumWeight += Weight;
                        SumMove += Weight * (MethodPoints.Get(s) - BaseClose);
                        SumWeightedSigma += Weight * MethodSigmas.Get(s);
                    end;
                    SumSigma += MethodSigmas.Get(s);
                    ValidCount += 1;
                end;
            if SumWeight > 0 then begin
                Points.Add(BaseClose + SumMove / SumWeight);
                Sigmas.Add(SumWeightedSigma / SumWeight);
            end else begin
                Points.Add(BaseClose);
                Sigmas.Add(SumSigma / ValidCount);
            end;
        end;
    end;

    local procedure IsComponent(Ordinal: Integer): Boolean
    begin
        // composite methods are not weighted again
        exit(not (Ordinal in ["SMA Forecast Method"::Ensemble.AsInteger(),
                              "SMA Forecast Method"::"Weighted Ensemble".AsInteger(),
                              "SMA Forecast Method"::"Adaptive (Live)".AsInteger()]));
    end;
}
