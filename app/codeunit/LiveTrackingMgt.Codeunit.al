/// <summary>
/// Live learning loop, run by the job queue for every active pair:
/// 1. every Tracking Interval minutes records the forecast of every method for every signal expirations;
/// 2. when the target candle is complete, compares the forecast with the actual price;
/// 3. updates the score of the method (recent results weigh more) and re-ranks the methods per expiration.
/// The Adaptive (Live) method combines the methods by these weights.
/// </summary>
codeunit 50125 "SMA Live Tracking Mgt"
{
    Permissions =
        tabledata "SMA Currency Pair" = rm,
        tabledata "SMA Rate Candle" = r,
        tabledata "SMA Tracked Forecast" = rimd,
        tabledata "SMA Method Score" = rimd;

    var
        ForecastMath: Codeunit "SMA Forecast Math";
        RateHelper: Codeunit "SMA Rate Helper";

    /// <summary>
    /// Records the forecasts of all methods if the tracking interval has passed since the last snapshot.
    /// </summary>
    procedure TrackPair(var CurrencyPair: Record "SMA Currency Pair")
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        TrackedForecast: Record "SMA Tracked Forecast";
        ForecastContext: Codeunit "SMA Forecast Context";
        ForecastEngine: Codeunit "SMA Forecast Engine";
        ForecastMgt: Codeunit "SMA Forecast Mgt";
        TradeSignalMgt: Codeunit "SMA Trade Signal Mgt";
        ForecastMethod: Enum "SMA Forecast Method";
        Expirations: List of [Integer];
        StepsList: List of [Integer];
        Points: List of [Decimal];
        Sigmas: List of [Decimal];
        TimeframeDuration: Duration;
        IntervalMs: BigInteger;
        BaseTime: DateTime;
        BaseClose: Decimal;
        Ordinal: Integer;
        MaxSteps: Integer;
        k: Integer;
    begin
        RateAnalyzerSetup.GetRecordOnce();
        if RateAnalyzerSetup."Disable Live Tracking" then
            exit;
        IntervalMs := RateAnalyzerSetup.GetTrackingIntervalMin();
        IntervalMs := IntervalMs * 60000 - 5000; // the job queue does not start exactly on the minute
        // AL evaluates both operands of "and", so the subtraction must not run on an empty date
        if CurrencyPair."Last Tracking At" <> 0DT then
            if CurrentDateTime() - CurrencyPair."Last Tracking At" < IntervalMs then
                exit;

        TradeSignalMgt.GetExpirations(CurrencyPair, RateAnalyzerSetup, Expirations, StepsList);
        MaxSteps := StepsList.Get(StepsList.Count());
        // the base is the last complete candle: its close is a known price, the outcome is the close exactly Steps candles later
        ForecastContext.Load(CurrencyPair, RateAnalyzerSetup."Lookback Candles" + RateAnalyzerSetup.GetHistoryCandles() + MaxSteps + 1, true);
        if ForecastContext.CandleCount() < ForecastMgt.MinCandles() then
            exit;
        BaseTime := ForecastContext.TimeAt(ForecastContext.CandleCount());
        BaseClose := ForecastContext.CloseAt(ForecastContext.CandleCount());
        TimeframeDuration := RateHelper.GetTimeframeDuration(CurrencyPair.Timeframe);

        TrackedForecast.SetRange("Pair Code", CurrencyPair.Code);
        TrackedForecast.SetRange(Timeframe, CurrencyPair.Timeframe);
        TrackedForecast.SetRange("Base Time", BaseTime);
        if TrackedForecast.IsEmpty() then
            foreach Ordinal in Enum::"SMA Forecast Method".Ordinals() do begin
                ForecastMethod := Enum::"SMA Forecast Method".FromInteger(Ordinal);
                ForecastContext.SetPosition(ForecastContext.CandleCount());
                ForecastEngine.GetForecast(ForecastContext, ForecastMethod, MaxSteps, Points, Sigmas);
                if Points.Count() >= MaxSteps then
                    for k := 1 to StepsList.Count() do begin
                        TrackedForecast.Init();
                        TrackedForecast."Pair Code" := CurrencyPair.Code;
                        TrackedForecast.Timeframe := CurrencyPair.Timeframe;
                        TrackedForecast."Base Time" := BaseTime;
                        TrackedForecast.Method := ForecastMethod;
                        TrackedForecast."Expiration (Min)" := Expirations.Get(k);
                        TrackedForecast.Steps := StepsList.Get(k);
                        TrackedForecast."Target Time" := BaseTime + TimeframeDuration * StepsList.Get(k);
                        TrackedForecast."Base Close" := BaseClose;
                        TrackedForecast."Predicted Close" := Points.Get(StepsList.Get(k));
                        TrackedForecast.Direction := ToDirection(Points.Get(StepsList.Get(k)) - BaseClose);
                        TrackedForecast."Created At" := CurrentDateTime();
                        TrackedForecast.Insert();
                    end;
            end;

        CurrencyPair."Last Tracking At" := CurrentDateTime();
        CurrencyPair.Modify();
    end;

    /// <summary>
    /// Compares matured tracked forecasts with the actual close, learns from the results and re-ranks the methods.
    /// </summary>
    procedure EvaluatePair(CurrencyPair: Record "SMA Currency Pair")
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        RateCandle: Record "SMA Rate Candle";
        TargetRateCandle: Record "SMA Rate Candle";
        TrackedForecast: Record "SMA Tracked Forecast";
        TrackedForecastToUpdate: Record "SMA Tracked Forecast";
        LastCompleteTime: DateTime;
        Learned: Boolean;
    begin
        RateCandle.SetRange("Pair Code", CurrencyPair.Code);
        RateCandle.SetRange(Timeframe, CurrencyPair.Timeframe);
        RateCandle.SetRange(Complete, true);
        RateCandle.SetLoadFields("Open Time");
        if not RateCandle.FindLast() then
            exit;
        LastCompleteTime := RateCandle."Open Time";

        TrackedForecast.SetCurrentKey("Pair Code", Timeframe, Evaluated, "Target Time");
        TrackedForecast.SetRange("Pair Code", CurrencyPair.Code);
        TrackedForecast.SetRange(Timeframe, CurrencyPair.Timeframe);
        TrackedForecast.SetRange(Evaluated, false);
        TrackedForecast.SetRange("Target Time", 0DT, LastCompleteTime);
        if not TrackedForecast.FindSet() then
            exit;

        RateAnalyzerSetup.GetRecordOnce();
        repeat
            TrackedForecastToUpdate := TrackedForecast;
            if TargetRateCandle.Get(TrackedForecast."Pair Code", TrackedForecast.Timeframe, TrackedForecast."Target Time") then begin
                TrackedForecastToUpdate."Actual Close" := TargetRateCandle.Close;
                TrackedForecastToUpdate."Actual Direction" := ToDirection(TargetRateCandle.Close - TrackedForecast."Base Close");
                TrackedForecastToUpdate.Counted :=
                    (TrackedForecast.Direction <> "SMA Trade Direction"::None) and
                    (TrackedForecastToUpdate."Actual Direction" <> "SMA Trade Direction"::None);
                TrackedForecastToUpdate.Hit := TrackedForecastToUpdate.Counted and (TrackedForecast.Direction = TrackedForecastToUpdate."Actual Direction");
                TrackedForecastToUpdate.Evaluated := true;
                TrackedForecastToUpdate."Evaluated At" := CurrentDateTime();
                TrackedForecastToUpdate.Modify();
                if TrackedForecastToUpdate.Counted then begin
                    UpdateScore(TrackedForecastToUpdate, RateAnalyzerSetup.GetLearningDecay());
                    Learned := true;
                end;
            end else
                // no candle at the target time (market closed) - the forecast cannot be evaluated
                TrackedForecastToUpdate.Delete();
        until TrackedForecast.Next() = 0;

        if Learned then
            RecalculatePriorities(CurrencyPair.Code, CurrencyPair.Timeframe, RateAnalyzerSetup.GetMinLiveSamples());
    end;

    /// <summary>
    /// Deletes the learned scores of the pair (the tracked forecasts are kept, but will not be learned again).
    /// </summary>
    procedure ResetLearning(PairCode: Code[20]; Timeframe: Enum "SMA Rate Timeframe")
    var
        MethodScore: Record "SMA Method Score";
    begin
        MethodScore.SetRange("Pair Code", PairCode);
        MethodScore.SetRange(Timeframe, Timeframe);
        MethodScore.DeleteAll();
    end;

    local procedure UpdateScore(TrackedForecast: Record "SMA Tracked Forecast"; Decay: Decimal)
    var
        MethodScore: Record "SMA Method Score";
        HitValue: Integer;
    begin
        if not MethodScore.Get(TrackedForecast."Pair Code", TrackedForecast.Timeframe, TrackedForecast.Method, TrackedForecast."Expiration (Min)") then begin
            MethodScore.Init();
            MethodScore."Pair Code" := TrackedForecast."Pair Code";
            MethodScore.Timeframe := TrackedForecast.Timeframe;
            MethodScore.Method := TrackedForecast.Method;
            MethodScore."Expiration (Min)" := TrackedForecast."Expiration (Min)";
            MethodScore.Insert();
        end;
        if TrackedForecast.Hit then
            HitValue := 1;
        MethodScore.Samples += 1;
        MethodScore.Hits += HitValue;
        MethodScore."Hit Rate %" := Round(MethodScore.Hits / MethodScore.Samples * 100, 0.01);
        // exponential forgetting: every new result makes all older results count Decay times less
        MethodScore."Decayed Samples" := MethodScore."Decayed Samples" * Decay + 1;
        MethodScore."Decayed Hits" := MethodScore."Decayed Hits" * Decay + HitValue;
        // Laplace smoothing keeps methods with few results close to 50%
        MethodScore."Recent Hit Rate %" := Round((MethodScore."Decayed Hits" + 1) / (MethodScore."Decayed Samples" + 2) * 100, 0.01);
        MethodScore."Last Evaluated At" := CurrentDateTime();
        MethodScore.Modify();
    end;

    local procedure RecalculatePriorities(PairCode: Code[20]; Timeframe: Enum "SMA Rate Timeframe"; MinSamples: Integer)
    var
        MethodScore: Record "SMA Method Score";
        Expirations: List of [Integer];
        Minutes: Integer;
        Priority: Integer;
    begin
        MethodScore.SetRange("Pair Code", PairCode);
        MethodScore.SetRange(Timeframe, Timeframe);
        MethodScore.SetLoadFields("Expiration (Min)");
        if MethodScore.FindSet() then
            repeat
                if not Expirations.Contains(MethodScore."Expiration (Min)") then
                    Expirations.Add(MethodScore."Expiration (Min)");
            until MethodScore.Next() = 0;
        MethodScore.SetLoadFields();

        MethodScore.SetCurrentKey("Pair Code", Timeframe, "Expiration (Min)", "Recent Hit Rate %");
        MethodScore.Ascending(false);
        foreach Minutes in Expirations do begin
            Priority := 0;
            MethodScore.SetRange("Expiration (Min)", Minutes);
            // methods with enough results first, best first; then the rest without weight
            MethodScore.SetFilter(Samples, '>=%1', MinSamples);
            if MethodScore.FindSet() then
                repeat
                    Priority += 1;
                    MethodScore.Priority := Priority;
                    MethodScore.Weight := MethodScore."Recent Hit Rate %" / 100 - 0.5;
                    if MethodScore.Weight < 0 then
                        MethodScore.Weight := 0;
                    MethodScore.Modify();
                until MethodScore.Next() = 0;
            MethodScore.SetFilter(Samples, '<%1', MinSamples);
            if MethodScore.FindSet() then
                repeat
                    Priority += 1;
                    MethodScore.Priority := Priority;
                    MethodScore.Weight := 0;
                    MethodScore.Modify();
                until MethodScore.Next() = 0;
            MethodScore.SetRange(Samples);
        end;
    end;

    local procedure ToDirection(Change: Decimal): Enum "SMA Trade Direction"
    begin
        case ForecastMath.Sign(Change) of
            1:
                exit("SMA Trade Direction"::Up);
            -1:
                exit("SMA Trade Direction"::Down);
        end;
        exit("SMA Trade Direction"::None);
    end;
}
