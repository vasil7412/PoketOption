/// <summary>
/// Adaptive (Live): combines the single methods by the weights they earned on the live tracked forecasts of the pair
/// (see codeunit "SMA Live Tracking Mgt"). The best methods dominate, methods at or below 50% are ignored.
/// The weights are known only for now, so the method works only at the newest candle and gives no historical forecasts:
/// its accuracy is the live track record in the method ranking.
/// </summary>
codeunit 50126 "SMA Adaptive Fcst" implements "SMA IForecast Method"
{
    Access = Internal;

    var
        ForecastEngine: Codeunit "SMA Forecast Engine";
        RateHelper: Codeunit "SMA Rate Helper";

    procedure Forecast(var ForecastContext: Codeunit "SMA Forecast Context"; Steps: Integer; var Points: List of [Decimal]; var Sigmas: List of [Decimal])
    var
        Components: List of [Integer];
        ComponentPoints: Dictionary of [Integer, List of [Decimal]];
        ComponentSigmas: Dictionary of [Integer, List of [Decimal]];
        Weights: Dictionary of [Integer, Decimal];
        MethodPoints: List of [Decimal];
        MethodSigmas: List of [Decimal];
        BaseClose: Decimal;
        Weight: Decimal;
        SumWeight: Decimal;
        SumMove: Decimal;
        SumWeightedSigma: Decimal;
        SumSigma: Decimal;
        Ordinal: Integer;
        TimeframeSeconds: Integer;
        Minutes: Integer;
        s: Integer;
    begin
        Clear(Points);
        Clear(Sigmas);
        // live weights describe the present only
        if (ForecastContext.Position() <> ForecastContext.CandleCount()) or (ForecastContext.CandleCount() < 2) then
            exit;

        foreach Ordinal in Enum::"SMA Forecast Method".Ordinals() do
            if IsComponent(Ordinal) then begin
                ForecastEngine.GetForecast(ForecastContext, Enum::"SMA Forecast Method".FromInteger(Ordinal), Steps, MethodPoints, MethodSigmas);
                if MethodPoints.Count() >= Steps then begin
                    Components.Add(Ordinal);
                    ComponentPoints.Add(Ordinal, MethodPoints);
                    ComponentSigmas.Add(Ordinal, MethodSigmas);
                end;
            end;
        if Components.Count() = 0 then
            exit;

        TimeframeSeconds := RateHelper.GetTimeframeSeconds(ForecastContext.PairTimeframe());
        BaseClose := ForecastContext.CloseAt(ForecastContext.Position());
        for s := 1 to Steps do begin
            Minutes := (s * TimeframeSeconds + 59) div 60;
            SumWeight := 0;
            SumMove := 0;
            SumWeightedSigma := 0;
            SumSigma := 0;
            foreach Ordinal in Components do begin
                ComponentPoints.Get(Ordinal, MethodPoints);
                ComponentSigmas.Get(Ordinal, MethodSigmas);
                Weight := GetWeight(ForecastContext, Ordinal, Minutes, Weights);
                if Weight > 0 then begin
                    SumWeight += Weight;
                    SumMove += Weight * (MethodPoints.Get(s) - BaseClose);
                    SumWeightedSigma += Weight * MethodSigmas.Get(s);
                end;
                SumSigma += MethodSigmas.Get(s);
            end;
            if SumWeight > 0 then begin
                Points.Add(BaseClose + SumMove / SumWeight);
                Sigmas.Add(SumWeightedSigma / SumWeight);
            end else begin
                // no method has proven itself yet: no signal
                Points.Add(BaseClose);
                Sigmas.Add(SumSigma / Components.Count());
            end;
        end;
    end;

    /// <summary>
    /// Weight of the method for the shortest tracked expiration that covers Minutes (or the longest tracked one).
    /// </summary>
    local procedure GetWeight(var ForecastContext: Codeunit "SMA Forecast Context"; Ordinal: Integer; Minutes: Integer; var Weights: Dictionary of [Integer, Decimal]): Decimal
    var
        MethodScore: Record "SMA Method Score";
        CacheKey: Integer;
        Weight: Decimal;
    begin
        CacheKey := Ordinal * 1000 + Minutes;
        if Weights.Get(CacheKey, Weight) then
            exit(Weight);

        MethodScore.SetRange("Pair Code", ForecastContext.PairCode());
        MethodScore.SetRange(Timeframe, ForecastContext.PairTimeframe());
        MethodScore.SetRange(Method, Enum::"SMA Forecast Method".FromInteger(Ordinal));
        MethodScore.SetLoadFields(Weight);
        MethodScore.SetFilter("Expiration (Min)", '>=%1', Minutes);
        if MethodScore.FindFirst() then
            Weight := MethodScore.Weight
        else begin
            MethodScore.SetRange("Expiration (Min)");
            if MethodScore.FindLast() then
                Weight := MethodScore.Weight;
        end;
        Weights.Add(CacheKey, Weight);
        exit(Weight);
    end;

    local procedure IsComponent(Ordinal: Integer): Boolean
    begin
        // composite methods are not weighted again
        exit(not (Ordinal in ["SMA Forecast Method"::Ensemble.AsInteger(),
                              "SMA Forecast Method"::"Weighted Ensemble".AsInteger(),
                              "SMA Forecast Method"::"Adaptive (Live)".AsInteger()]));
    end;
}
