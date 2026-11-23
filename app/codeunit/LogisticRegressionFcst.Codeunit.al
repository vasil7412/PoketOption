/// <summary>
/// Logistic regression of the direction: instead of the price it predicts the probability that the close Steps candles later
/// is above the current close. Features of every candle: z-score to the moving average (and its cube for extremes), RSI,
/// stochastic %K, the last candle body, the 5-candle move, the streak of same-colored candles and the wick asymmetry.
/// One model per horizon (1, 2, 3, 5, 10, 15, 30, 60 candles and Steps) is fitted by ridge-regularized Newton iterations
/// on the Training Candles before the position and refitted every Refit Interval candles. Steps between the fitted horizons
/// use the nearest shorter horizon. The method only gives a direction if the probability reaches the Min. Probability,
/// otherwise the forecast is flat (no trade).
/// </summary>
codeunit 50128 "SMA Logistic Regression Fcst" implements "SMA IForecast Method"
{
    Access = Internal;

    var
        ForecastMath: Codeunit "SMA Forecast Math";
        FeatureKeyTok: Label 'LR:F:%1', Locked = true;
        ModelKeyTok: Label 'LR:M:%1', Locked = true;

    procedure Forecast(var ForecastContext: Codeunit "SMA Forecast Context"; Steps: Integer; var Points: List of [Decimal]; var Sigmas: List of [Decimal])
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        Weights: List of [Decimal];
        Features: List of [Decimal];
        Horizons: List of [Integer];
        Probabilities: Dictionary of [Integer, Decimal];
        Probability: Decimal;
        Threshold: Decimal;
        StepSigma: Decimal;
        Price: Decimal;
        Horizon: Integer;
        UsedHorizon: Integer;
        Position: Integer;
        Step: Integer;
    begin
        Clear(Points);
        Clear(Sigmas);
        ForecastContext.GetSetup(RateAnalyzerSetup);
        Position := ForecastContext.Position();
        if Position <= WarmupCandles(RateAnalyzerSetup) then
            exit;
        // the features need a window without missing candles (no forecast right after a gap or the weekend)
        if not ForecastContext.IsContinuous(Position - WarmupCandles(RateAnalyzerSetup), Position) then
            exit;
        StepSigma := ForecastMath.ChangeStdDev(ForecastContext.WindowCloses());
        Price := ForecastContext.CloseAt(Position);
        Features := GetFeatures(ForecastContext, RateAnalyzerSetup, Position);

        GetHorizons(Steps, Horizons);
        foreach Horizon in Horizons do begin
            if not GetModel(ForecastContext, RateAnalyzerSetup, Horizon, Weights) then
                exit;
            Probabilities.Add(Horizon, Predict(Weights, Features));
        end;

        Threshold := RateAnalyzerSetup.GetLogisticMinProbability() / 100;
        for Step := 1 to Steps do begin
            foreach Horizon in Horizons do
                if Horizon <= Step then
                    UsedHorizon := Horizon;
            Probability := Probabilities.Get(UsedHorizon);
            // expected move: (2p - 1) * E|change|, E|change| = sigma * sqrt(2 / pi) for a normal move
            if (Probability >= Threshold) or (Probability <= 1 - Threshold) then
                Points.Add(Price + (2 * Probability - 1) * StepSigma * ForecastMath.Sqrt(Step) * 0.7979)
            else
                Points.Add(Price);
            Sigmas.Add(StepSigma * ForecastMath.Sqrt(Step));
        end;
    end;

    local procedure GetHorizons(Steps: Integer; var Horizons: List of [Integer])
    var
        Candidates: List of [Integer];
        Horizon: Integer;
    begin
        Candidates.AddRange(1, 2, 3, 5, 10, 15, 30, 60);
        foreach Horizon in Candidates do
            if Horizon < Steps then
                Horizons.Add(Horizon);
        Horizons.Add(Steps);
    end;

    /// <summary>
    /// Returns the model of the horizon fitted at most Refit Interval - 1 candles before the position, fitting a new one if there is none.
    /// </summary>
    local procedure GetModel(var ForecastContext: Codeunit "SMA Forecast Context"; RateAnalyzerSetup: Record "SMA Rate Analyzer Setup"; Horizon: Integer; var Weights: List of [Decimal]): Boolean
    var
        Model: List of [Decimal];
        FitPosition: Integer;
        Position: Integer;
    begin
        Position := ForecastContext.Position();
        if ForecastContext.TryGetMethodState(StrSubstNo(ModelKeyTok, Horizon), Model) then begin
            FitPosition := Model.Get(1) div 1;
            if (FitPosition <= Position) and (Position - FitPosition < RateAnalyzerSetup.GetLogisticRefitInterval()) then
                exit(TryGetWeights(Model, Weights));
        end;

        Model := FitModel(ForecastContext, RateAnalyzerSetup, Horizon);
        ForecastContext.SetMethodState(StrSubstNo(ModelKeyTok, Horizon), Model);
        exit(TryGetWeights(Model, Weights));
    end;

    local procedure TryGetWeights(Model: List of [Decimal]; var Weights: List of [Decimal]): Boolean
    begin
        // the first item is the fit position; a model without weights had too few samples
        if Model.Count() < 2 then
            exit(false);
        Weights := Model.GetRange(2, Model.Count() - 1);
        exit(true);
    end;

    /// <summary>
    /// Fits the model on the candles before the position whose outcome Horizon candles later is known.
    /// Returns the fit position followed by the weights (bias first); no weights if there are too few samples.
    /// </summary>
    local procedure FitModel(var ForecastContext: Codeunit "SMA Forecast Context"; RateAnalyzerSetup: Record "SMA Rate Analyzer Setup"; Horizon: Integer): List of [Decimal]
    var
        Model: List of [Decimal];
        Samples: List of [List of [Decimal]];
        Labels: List of [Integer];
        Features: List of [Decimal];
        Hessian: array[9, 9] of Decimal;
        Gradient: array[9] of Decimal;
        Delta: array[9] of Decimal;
        W: array[9] of Decimal;
        X: array[9] of Decimal;
        Probability: Decimal;
        Curvature: Decimal;
        Ridge: Decimal;
        MaxDelta: Decimal;
        Position: Integer;
        FromIndex: Integer;
        Direction: Integer;
        Size: Integer;
        Iteration: Integer;
        s: Integer;
        t: Integer;
        i: Integer;
        j: Integer;
    begin
        Position := ForecastContext.Position();
        Model.Add(Position);
        FromIndex := Position - Horizon - RateAnalyzerSetup.GetLogisticTrainingCandles() + 1;
        if FromIndex <= WarmupCandles(RateAnalyzerSetup) then
            FromIndex := WarmupCandles(RateAnalyzerSetup) + 1;

        for t := FromIndex to Position - Horizon do
            // the outcome must be a finished candle exactly Horizon timeframes later, and the feature window must have no gap;
            // an unchanged price is a refund and teaches nothing
            if ForecastContext.IsComplete(t + Horizon) and ForecastContext.IsContinuous(t - WarmupCandles(RateAnalyzerSetup), t + Horizon) then begin
                Direction := ForecastMath.Sign(ForecastContext.CloseAt(t + Horizon) - ForecastContext.CloseAt(t));
                if Direction <> 0 then begin
                    Samples.Add(GetFeatures(ForecastContext, RateAnalyzerSetup, t));
                    if Direction > 0 then
                        Labels.Add(1)
                    else
                        Labels.Add(0);
                end;
            end;
        if Samples.Count() < MinSamples() then
            exit(Model);

        Size := FeatureCount() + 1;
        // ridge keeps the weights near zero on noise, so a short history cannot produce confident probabilities
        Ridge := Samples.Count() * 0.01;
        for Iteration := 1 to 8 do begin
            Clear(Hessian);
            Clear(Gradient);
            for s := 1 to Samples.Count() do begin
                Features := Samples.Get(s);
                X[1] := 1;
                for i := 2 to Size do
                    X[i] := Features.Get(i - 1);
                Probability := Sigmoid(W, X, Size);
                Curvature := Probability * (1 - Probability);
                for i := 1 to Size do begin
                    Gradient[i] += (Labels.Get(s) - Probability) * X[i];
                    for j := i to Size do
                        Hessian[i, j] += Curvature * X[i] * X[j];
                end;
            end;
            for i := 1 to Size do
                for j := 1 to i - 1 do
                    Hessian[i, j] := Hessian[j, i];
            Hessian[1, 1] += 0.000001;
            for i := 2 to Size do begin
                Gradient[i] -= Ridge * W[i];
                Hessian[i, i] += Ridge;
            end;
            if not Solve(Hessian, Gradient, Size, Delta) then
                exit(Model);
            MaxDelta := 0;
            for i := 1 to Size do begin
                W[i] += Delta[i];
                if Abs(Delta[i]) > MaxDelta then
                    MaxDelta := Abs(Delta[i]);
            end;
            if MaxDelta < 0.0001 then
                break;
        end;

        for i := 1 to Size do
            Model.Add(W[i]);
        exit(Model);
    end;

    local procedure Predict(Weights: List of [Decimal]; Features: List of [Decimal]): Decimal
    var
        W: array[9] of Decimal;
        X: array[9] of Decimal;
        i: Integer;
    begin
        X[1] := 1;
        for i := 1 to Weights.Count() do
            W[i] := Weights.Get(i);
        for i := 2 to Weights.Count() do
            X[i] := Features.Get(i - 1);
        exit(Sigmoid(W, X, Weights.Count()));
    end;

    local procedure Sigmoid(W: array[9] of Decimal; X: array[9] of Decimal; Size: Integer): Decimal
    var
        Score: Decimal;
        i: Integer;
    begin
        for i := 1 to Size do
            Score += W[i] * X[i];
        if Score > 30 then
            Score := 30;
        if Score < -30 then
            Score := -30;
        exit(1 / (1 + ForecastMath.Exp(-Score)));
    end;

    /// <summary>
    /// Features of the candle at Index, computed from the candles up to Index only. Cached in the context.
    /// </summary>
    local procedure GetFeatures(var ForecastContext: Codeunit "SMA Forecast Context"; RateAnalyzerSetup: Record "SMA Rate Analyzer Setup"; Index: Integer): List of [Decimal]
    var
        Features: List of [Decimal];
        Average: Decimal;
        LevelStdDev: Decimal;
        ChangeSigma: Decimal;
        Change: Decimal;
        SumSquares: Decimal;
        Gains: Decimal;
        Losses: Decimal;
        HighestHigh: Decimal;
        LowestLow: Decimal;
        CandleRange: Decimal;
        UpperWick: Decimal;
        LowerWick: Decimal;
        ZScore: Decimal;
        Period: Integer;
        Streak: Integer;
        Color: Integer;
        i: Integer;
    begin
        if ForecastContext.TryGetMethodState(StrSubstNo(FeatureKeyTok, Index), Features) then
            exit(Features);

        // z-score of the close to the moving average and the volatility of one-candle changes
        Period := RateAnalyzerSetup.GetMeanReversionPeriod();
        for i := Index - Period + 1 to Index do
            Average += ForecastContext.CloseAt(i);
        Average := Average / Period;
        for i := Index - Period + 1 to Index do begin
            SumSquares += Power(ForecastContext.CloseAt(i) - Average, 2);
            Change := ForecastContext.CloseAt(i) - ForecastContext.CloseAt(i - 1);
            ChangeSigma += Change * Change;
        end;
        LevelStdDev := ForecastMath.Sqrt(SumSquares / (Period - 1));
        ChangeSigma := ForecastMath.Sqrt(ChangeSigma / Period);
        if LevelStdDev > 0 then
            ZScore := Clip((ForecastContext.CloseAt(Index) - Average) / LevelStdDev, 3);
        Features.Add(ZScore);
        Features.Add(ZScore * ZScore * ZScore / 9);

        // RSI (simple averages), centered: -1 = all losses, 1 = all gains
        Period := RateAnalyzerSetup.GetRSIPeriod();
        for i := Index - Period + 1 to Index do begin
            Change := ForecastContext.CloseAt(i) - ForecastContext.CloseAt(i - 1);
            if Change > 0 then
                Gains += Change
            else
                Losses -= Change;
        end;
        if Gains + Losses > 0 then
            Features.Add((Gains - Losses) / (Gains + Losses))
        else
            Features.Add(0);

        // stochastic %K, centered: -1 = at the lowest low, 1 = at the highest high
        Period := RateAnalyzerSetup.GetStochasticPeriod();
        HighestHigh := ForecastContext.HighAt(Index);
        LowestLow := ForecastContext.LowAt(Index);
        for i := Index - Period + 1 to Index do begin
            if ForecastContext.HighAt(i) > HighestHigh then
                HighestHigh := ForecastContext.HighAt(i);
            if ForecastContext.LowAt(i) < LowestLow then
                LowestLow := ForecastContext.LowAt(i);
        end;
        if HighestHigh > LowestLow then
            Features.Add(2 * (ForecastContext.CloseAt(Index) - LowestLow) / (HighestHigh - LowestLow) - 1)
        else
            Features.Add(0);

        // the last candle body and the 5-candle move in typical changes
        if ChangeSigma > 0 then begin
            Features.Add(Clip((ForecastContext.CloseAt(Index) - ForecastContext.OpenAt(Index)) / ChangeSigma, 3));
            Features.Add(Clip((ForecastContext.CloseAt(Index) - ForecastContext.CloseAt(Index - 5)) / (ChangeSigma * ForecastMath.Sqrt(5)), 3));
        end else begin
            Features.Add(0);
            Features.Add(0);
        end;

        // streak of candles of the same color, signed
        Color := ForecastMath.Sign(ForecastContext.CloseAt(Index) - ForecastContext.OpenAt(Index));
        if Color <> 0 then begin
            i := Index;
            while (i >= 1) and (Streak < 5) do begin
                if ForecastMath.Sign(ForecastContext.CloseAt(i) - ForecastContext.OpenAt(i)) <> Color then
                    break;
                Streak += 1;
                i -= 1;
            end;
        end;
        Features.Add(Color * Streak / 5);

        // wick asymmetry: 1 = only a lower wick (buyers rejected the low), -1 = only an upper wick
        CandleRange := ForecastContext.HighAt(Index) - ForecastContext.LowAt(Index);
        if CandleRange > 0 then begin
            UpperWick := ForecastContext.HighAt(Index) - Larger(ForecastContext.OpenAt(Index), ForecastContext.CloseAt(Index));
            LowerWick := Smaller(ForecastContext.OpenAt(Index), ForecastContext.CloseAt(Index)) - ForecastContext.LowAt(Index);
            Features.Add((LowerWick - UpperWick) / CandleRange);
        end else
            Features.Add(0);

        ForecastContext.SetMethodState(StrSubstNo(FeatureKeyTok, Index), Features);
        exit(Features);
    end;

    local procedure FeatureCount(): Integer
    begin
        exit(8);
    end;

    local procedure MinSamples(): Integer
    begin
        exit(50);
    end;

    /// <summary>
    /// Candles needed before the first candle with features.
    /// </summary>
    local procedure WarmupCandles(RateAnalyzerSetup: Record "SMA Rate Analyzer Setup"): Integer
    var
        Warmup: Integer;
    begin
        Warmup := 6;
        if RateAnalyzerSetup.GetMeanReversionPeriod() + 1 > Warmup then
            Warmup := RateAnalyzerSetup.GetMeanReversionPeriod() + 1;
        if RateAnalyzerSetup.GetRSIPeriod() + 1 > Warmup then
            Warmup := RateAnalyzerSetup.GetRSIPeriod() + 1;
        if RateAnalyzerSetup.GetStochasticPeriod() > Warmup then
            Warmup := RateAnalyzerSetup.GetStochasticPeriod();
        exit(Warmup);
    end;

    local procedure Clip(Value: Decimal; Limit: Decimal): Decimal
    begin
        if Value > Limit then
            exit(Limit);
        if Value < -Limit then
            exit(-Limit);
        exit(Value);
    end;

    local procedure Larger(Value1: Decimal; Value2: Decimal): Decimal
    begin
        if Value1 > Value2 then
            exit(Value1);
        exit(Value2);
    end;

    local procedure Smaller(Value1: Decimal; Value2: Decimal): Decimal
    begin
        if Value1 < Value2 then
            exit(Value1);
        exit(Value2);
    end;

    /// <summary>
    /// Solves A * X = B by Gaussian elimination with partial pivoting. A and B are destroyed.
    /// </summary>
    local procedure Solve(var A: array[9, 9] of Decimal; var B: array[9] of Decimal; Size: Integer; var X: array[9] of Decimal): Boolean
    var
        Factor: Decimal;
        Swap: Decimal;
        Sum: Decimal;
        Pivot: Integer;
        Col: Integer;
        Row: Integer;
        c: Integer;
    begin
        for Col := 1 to Size do begin
            Pivot := Col;
            for Row := Col + 1 to Size do
                if Abs(A[Row, Col]) > Abs(A[Pivot, Col]) then
                    Pivot := Row;
            if Abs(A[Pivot, Col]) < 0.000000001 then
                exit(false);
            if Pivot <> Col then begin
                for c := 1 to Size do begin
                    Swap := A[Col, c];
                    A[Col, c] := A[Pivot, c];
                    A[Pivot, c] := Swap;
                end;
                Swap := B[Col];
                B[Col] := B[Pivot];
                B[Pivot] := Swap;
            end;
            for Row := Col + 1 to Size do begin
                Factor := A[Row, Col] / A[Col, Col];
                for c := Col to Size do
                    A[Row, c] -= Factor * A[Col, c];
                B[Row] -= Factor * B[Col];
            end;
        end;
        for Row := Size downto 1 do begin
            Sum := B[Row];
            for c := Row + 1 to Size do
                Sum -= A[Row, c] * X[c];
            X[Row] := Sum / A[Row, Row];
        end;
        exit(true);
    end;
}
