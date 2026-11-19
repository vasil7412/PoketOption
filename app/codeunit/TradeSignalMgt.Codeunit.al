/// <summary>
/// Builds trade hints: for every forecast method and expiration takes the current predicted direction
/// and checks on the recent history how often the same method guessed the direction for that expiration
/// (optionally only at the current hour of the day). The conservative hit rate is corrected for the number of
/// compared candidates. A trade is recommended if it beats the breakeven of the payout and no other method
/// with a proven edge predicts the opposite direction.
/// </summary>
codeunit 50116 "SMA Trade Signal Mgt"
{
    Permissions =
        tabledata "SMA Rate Candle" = r,
        tabledata "SMA Method Score" = r;

    var
        ForecastMath: Codeunit "SMA Forecast Math";
        ForecastMgt: Codeunit "SMA Forecast Mgt";
        RateHelper: Codeunit "SMA Rate Helper";
        SignalHour: Integer;
        CandidateCount: Integer;
        TimeFilterUsed: Boolean;
        NotEnoughCandlesErr: Label 'There are not enough candles of %1 for a forecast yet.', Comment = '%1 = pair code';
        NoExpirationsErr: Label 'None of the signal expirations "%1" fits the %2 timeframe. Specify expirations in whole minutes in the Rate Analyzer Setup.', Comment = '%1 = expirations, %2 = timeframe';
        ProgressMsg: Label 'Analyzing #1####################', Comment = '#1 = method';

    /// <summary>
    /// Fills TempTradeSignal with one record per forecast method and expiration and marks the recommended one.
    /// </summary>
    /// <returns>True if a trade is recommended.</returns>
    procedure BuildSignals(CurrencyPair: Record "SMA Currency Pair"; var TempTradeSignal: Record "SMA Trade Signal" temporary): Boolean
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        ForecastContext: Codeunit "SMA Forecast Context";
        ForecastMethod: Enum "SMA Forecast Method";
        Window: Dialog;
        Expirations: List of [Integer];
        StepsList: List of [Integer];
        Ordinal: Integer;
        EntryNo: Integer;
        Lookback: Integer;
        StartPosition: Integer;
        LastComplete: Integer;
        MaxSteps: Integer;
    begin
        TempTradeSignal.Reset();
        TempTradeSignal.DeleteAll();
        RateAnalyzerSetup.GetRecordOnce();
        Lookback := RateAnalyzerSetup."Lookback Candles";
        TimeFilterUsed := RateAnalyzerSetup."Time-of-Day Filter";

        GetExpirations(CurrencyPair, RateAnalyzerSetup, Expirations, StepsList);
        MaxSteps := StepsList.Get(StepsList.Count());
        // warm-up candles: the window of the methods, the weighting history of the weighted ensemble and the training history of the logistic regression
        ForecastContext.Load(CurrencyPair,
            RateAnalyzerSetup.GetSignalBacktestCandles() + Lookback + RateAnalyzerSetup.GetHistoryCandles() + MaxSteps, false);
        if ForecastContext.CandleCount() < ForecastMgt.MinCandles() then
            Error(NotEnoughCandlesErr, CurrencyPair.Code);

        // the forming candle is the base of the current forecast but no outcome of the historical ones
        LastComplete := ForecastContext.CandleCount();
        if not ForecastContext.IsComplete(LastComplete) then
            LastComplete -= 1;
        StartPosition := Lookback + RateAnalyzerSetup.GetHistoryCandles();
        if StartPosition >= LastComplete then
            StartPosition := Lookback;
        SignalHour := GetHour(ForecastContext.TimeAt(ForecastContext.CandleCount()));

        if GuiAllowed() then
            Window.Open(ProgressMsg);
        foreach Ordinal in Enum::"SMA Forecast Method".Ordinals() do begin
            ForecastMethod := Enum::"SMA Forecast Method".FromInteger(Ordinal);
            if GuiAllowed() then
                Window.Update(1, Format(ForecastMethod));
            AddMethodSignals(CurrencyPair, ForecastMethod, ForecastContext, StartPosition, LastComplete,
                Expirations, StepsList, RateAnalyzerSetup.GetBreakevenPct(), TempTradeSignal, EntryNo);
        end;
        if GuiAllowed() then
            Window.Close();

        ComputeStatistics(TempTradeSignal);
        MarkAgreement(TempTradeSignal, Expirations, RateAnalyzerSetup.GetSignalMinSamples());
        exit(MarkRecommended(TempTradeSignal, RateAnalyzerSetup.GetSignalMinSamples()));
    end;

    /// <summary>
    /// Finds the candidate with the highest conservative hit rate that predicts any direction (used to explain why there is no trade).
    /// </summary>
    procedure FindBestCandidate(var TempTradeSignal: Record "SMA Trade Signal" temporary): Boolean
    var
        BestEntryNo: Integer;
        BestValue: Decimal;
    begin
        TempTradeSignal.Reset();
        TempTradeSignal.SetFilter(Direction, '<>%1', "SMA Trade Direction"::None);
        if not TempTradeSignal.FindSet() then begin
            TempTradeSignal.Reset();
            exit(false);
        end;
        BestValue := -1;
        BestEntryNo := 0;
        repeat
            if TempTradeSignal."Conservative Hit Rate %" > BestValue then begin
                BestValue := TempTradeSignal."Conservative Hit Rate %";
                BestEntryNo := TempTradeSignal."Entry No.";
            end;
        until TempTradeSignal.Next() = 0;
        TempTradeSignal.Reset();
        exit(TempTradeSignal.Get(BestEntryNo));
    end;

    /// <summary>
    /// Hour of the day (0..23, user time zone) of the base candle of the last built signal.
    /// </summary>
    procedure GetSignalHour(): Integer
    begin
        exit(SignalHour);
    end;

    procedure IsTimeFilterUsed(): Boolean
    begin
        exit(TimeFilterUsed);
    end;

    /// <summary>
    /// Number of candidates with a direction that were compared; the conservative hit rate is corrected for it.
    /// </summary>
    procedure GetCandidateCount(): Integer
    begin
        exit(CandidateCount);
    end;

    /// <summary>
    /// Samples the recommendation is based on: of the same hour with the time-of-day filter, all otherwise.
    /// </summary>
    procedure GetUsedSamples(TempTradeSignal: Record "SMA Trade Signal" temporary): Integer
    begin
        if TimeFilterUsed then
            exit(TempTradeSignal."Hour Samples");
        exit(TempTradeSignal.Samples);
    end;

    local procedure AddMethodSignals(CurrencyPair: Record "SMA Currency Pair"; ForecastMethod: Enum "SMA Forecast Method"; var ForecastContext: Codeunit "SMA Forecast Context"; StartPosition: Integer; LastComplete: Integer; Expirations: List of [Integer]; StepsList: List of [Integer]; BreakevenPct: Decimal; var TempTradeSignal: Record "SMA Trade Signal" temporary; var EntryNo: Integer)
    var
        ForecastEngine: Codeunit "SMA Forecast Engine";
        Points: List of [Decimal];
        Sigmas: List of [Decimal];
        Samples: array[60] of Integer;
        Hits: array[60] of Integer;
        HourSamples: array[60] of Integer;
        HourHits: array[60] of Integer;
        BaseClose: Decimal;
        SameHour: Boolean;
        PredictedDir: Integer;
        ActualDir: Integer;
        MaxSteps: Integer;
        Steps: Integer;
        i: Integer;
        k: Integer;
    begin
        MaxSteps := StepsList.Get(StepsList.Count());

        // walk forward over the history: one forecast per candle covers all expirations at once
        for i := StartPosition to LastComplete - 1 do begin
            ForecastContext.SetPosition(i);
            ForecastEngine.GetForecast(ForecastContext, ForecastMethod, MaxSteps, Points, Sigmas);
            if Points.Count() >= MaxSteps then begin
                BaseClose := ForecastContext.CloseAt(i);
                SameHour := GetHour(ForecastContext.TimeAt(i)) = SignalHour;
                for k := 1 to StepsList.Count() do begin
                    Steps := StepsList.Get(k);
                    if i + Steps <= LastComplete then begin
                        PredictedDir := ForecastMath.Sign(Points.Get(Steps) - BaseClose);
                        ActualDir := ForecastMath.Sign(ForecastContext.CloseAt(i + Steps) - BaseClose);
                        // no predicted move = no trade, no actual move = refund; neither says anything about accuracy
                        if (PredictedDir <> 0) and (ActualDir <> 0) then begin
                            Samples[k] += 1;
                            if PredictedDir = ActualDir then
                                Hits[k] += 1;
                            if SameHour then begin
                                HourSamples[k] += 1;
                                if PredictedDir = ActualDir then
                                    HourHits[k] += 1;
                            end;
                        end;
                    end;
                end;
            end;
        end;

        // the current forecast on the latest candles
        ForecastContext.SetPosition(ForecastContext.CandleCount());
        ForecastEngine.GetForecast(ForecastContext, ForecastMethod, MaxSteps, Points, Sigmas);
        if Points.Count() < MaxSteps then
            exit;
        BaseClose := ForecastContext.CloseAt(ForecastContext.CandleCount());

        for k := 1 to StepsList.Count() do begin
            Steps := StepsList.Get(k);
            EntryNo += 1;
            TempTradeSignal.Init();
            TempTradeSignal."Entry No." := EntryNo;
            TempTradeSignal."Pair Code" := CurrencyPair.Code;
            TempTradeSignal.Method := ForecastMethod;
            TempTradeSignal."Expiration (Min)" := Expirations.Get(k);
            TempTradeSignal.Steps := Steps;
            TempTradeSignal."Base Time" := ForecastContext.TimeAt(ForecastContext.CandleCount());
            TempTradeSignal."Base Price" := BaseClose;
            TempTradeSignal."Predicted Price" := Points.Get(Steps);
            case ForecastMath.Sign(Points.Get(Steps) - BaseClose) of
                1:
                    TempTradeSignal.Direction := "SMA Trade Direction"::Up;
                -1:
                    TempTradeSignal.Direction := "SMA Trade Direction"::Down;
            end;
            if BaseClose <> 0 then
                TempTradeSignal."Expected Change %" := Round((Points.Get(Steps) - BaseClose) / BaseClose * 100, 0.0001);
            if Sigmas.Get(Steps) > 0 then
                TempTradeSignal.Strength := Round(Abs(Points.Get(Steps) - BaseClose) / Sigmas.Get(Steps), 0.01);
            TempTradeSignal.Samples := Samples[k];
            TempTradeSignal.Hits := Hits[k];
            if Samples[k] > 0 then
                TempTradeSignal."Hit Rate %" := Round(Hits[k] / Samples[k] * 100, 0.01);
            TempTradeSignal."Hour Samples" := HourSamples[k];
            TempTradeSignal."Hour Hits" := HourHits[k];
            if HourSamples[k] > 0 then
                TempTradeSignal."Hour Hit Rate %" := Round(HourHits[k] / HourSamples[k] * 100, 0.01);
            TempTradeSignal."Breakeven %" := BreakevenPct;
            AddLiveScore(TempTradeSignal);
            TempTradeSignal.Insert();
        end;
    end;

    /// <summary>
    /// Adds the live ranking of the method. The Adaptive (Live) method has no historical forecasts, so its live track record is its statistics.
    /// </summary>
    local procedure AddLiveScore(var TempTradeSignal: Record "SMA Trade Signal" temporary)
    var
        CurrencyPair: Record "SMA Currency Pair";
        MethodScore: Record "SMA Method Score";
    begin
        CurrencyPair.SetLoadFields(Timeframe);
        if not CurrencyPair.Get(TempTradeSignal."Pair Code") then
            exit;
        if not MethodScore.Get(TempTradeSignal."Pair Code", CurrencyPair.Timeframe, TempTradeSignal.Method, TempTradeSignal."Expiration (Min)") then
            exit;
        TempTradeSignal."Live Samples" := MethodScore.Samples;
        TempTradeSignal."Live Hit Rate %" := MethodScore."Recent Hit Rate %";
        TempTradeSignal."Live Priority" := MethodScore.Priority;
        if TempTradeSignal.Method = "SMA Forecast Method"::"Adaptive (Live)" then begin
            TempTradeSignal.Samples := MethodScore.Samples;
            TempTradeSignal.Hits := MethodScore.Hits;
            TempTradeSignal."Hit Rate %" := MethodScore."Hit Rate %";
        end;
    end;

    /// <summary>
    /// Conservative hit rate and edge of every candidate. The confidence level is corrected for the number of candidates
    /// with a direction (Bonferroni), because the best of many candidates looks good by luck alone.
    /// </summary>
    local procedure ComputeStatistics(var TempTradeSignal: Record "SMA Trade Signal" temporary)
    var
        Z: Decimal;
        UsedHits: Integer;
        UsedSamples: Integer;
    begin
        TempTradeSignal.Reset();
        TempTradeSignal.SetFilter(Direction, '<>%1', "SMA Trade Direction"::None);
        CandidateCount := TempTradeSignal.Count();
        if CandidateCount < 1 then
            CandidateCount := 1;
        Z := ForecastMath.NormalQuantile(1 - 0.05 / CandidateCount);

        TempTradeSignal.Reset();
        if not TempTradeSignal.FindSet() then
            exit;
        repeat
            UsedHits := TempTradeSignal.Hits;
            UsedSamples := TempTradeSignal.Samples;
            if TimeFilterUsed then begin
                UsedHits := TempTradeSignal."Hour Hits";
                UsedSamples := TempTradeSignal."Hour Samples";
            end;
            TempTradeSignal."Conservative Hit Rate %" := Round(ForecastMath.WilsonLowerBound(UsedHits, UsedSamples, Z) * 100, 0.01);
            TempTradeSignal."Edge %" := TempTradeSignal."Conservative Hit Rate %" - TempTradeSignal."Breakeven %";
            TempTradeSignal.Modify();
        until TempTradeSignal.Next() = 0;
    end;

    /// <summary>
    /// Counts agreeing and disagreeing methods per expiration and marks candidates that no method with a proven edge contradicts.
    /// </summary>
    local procedure MarkAgreement(var TempTradeSignal: Record "SMA Trade Signal" temporary; Expirations: List of [Integer]; MinSamples: Integer)
    var
        Minutes: Integer;
        UpCount: Integer;
        DownCount: Integer;
        ProvenUp: Integer;
        ProvenDown: Integer;
    begin
        foreach Minutes in Expirations do begin
            UpCount := 0;
            DownCount := 0;
            ProvenUp := 0;
            ProvenDown := 0;
            TempTradeSignal.Reset();
            TempTradeSignal.SetRange("Expiration (Min)", Minutes);
            if TempTradeSignal.FindSet() then
                repeat
                    case TempTradeSignal.Direction of
                        "SMA Trade Direction"::Up:
                            begin
                                UpCount += 1;
                                if IsProven(TempTradeSignal, MinSamples) then
                                    ProvenUp += 1;
                            end;
                        "SMA Trade Direction"::Down:
                            begin
                                DownCount += 1;
                                if IsProven(TempTradeSignal, MinSamples) then
                                    ProvenDown += 1;
                            end;
                    end;
                until TempTradeSignal.Next() = 0;

            if TempTradeSignal.FindSet() then
                repeat
                    case TempTradeSignal.Direction of
                        "SMA Trade Direction"::Up:
                            begin
                                TempTradeSignal."Agree Count" := UpCount - 1;
                                TempTradeSignal."Disagree Count" := DownCount;
                                TempTradeSignal."No Conflict" := ProvenDown = 0;
                            end;
                        "SMA Trade Direction"::Down:
                            begin
                                TempTradeSignal."Agree Count" := DownCount - 1;
                                TempTradeSignal."Disagree Count" := UpCount;
                                TempTradeSignal."No Conflict" := ProvenUp = 0;
                            end;
                    end;
                    TempTradeSignal.Modify();
                until TempTradeSignal.Next() = 0;
        end;
        TempTradeSignal.Reset();
    end;

    local procedure IsProven(TempTradeSignal: Record "SMA Trade Signal" temporary; MinSamples: Integer): Boolean
    begin
        exit((TempTradeSignal."Edge %" > 0) and (GetUsedSamples(TempTradeSignal) >= MinSamples));
    end;

    local procedure MarkRecommended(var TempTradeSignal: Record "SMA Trade Signal" temporary; MinSamples: Integer): Boolean
    var
        BestEntryNo: Integer;
        BestEdge: Decimal;
        BestMinutes: Integer;
    begin
        TempTradeSignal.Reset();
        TempTradeSignal.SetRange("No Conflict", true);
        TempTradeSignal.SetFilter(Direction, '<>%1', "SMA Trade Direction"::None);
        TempTradeSignal.SetFilter("Edge %", '>0');
        if not TempTradeSignal.FindSet() then begin
            TempTradeSignal.Reset();
            exit(false);
        end;
        BestEntryNo := 0;
        BestEdge := 0;
        BestMinutes := 0;
        repeat
            // the highest edge wins; on a tie the shorter expiration is preferred
            if GetUsedSamples(TempTradeSignal) >= MinSamples then
                if (BestEntryNo = 0) or (TempTradeSignal."Edge %" > BestEdge) or
                   ((TempTradeSignal."Edge %" = BestEdge) and (TempTradeSignal."Expiration (Min)" < BestMinutes))
                then begin
                    BestEntryNo := TempTradeSignal."Entry No.";
                    BestEdge := TempTradeSignal."Edge %";
                    BestMinutes := TempTradeSignal."Expiration (Min)";
                end;
        until TempTradeSignal.Next() = 0;

        TempTradeSignal.Reset();
        if BestEntryNo = 0 then
            exit(false);
        TempTradeSignal.Get(BestEntryNo);
        TempTradeSignal.Recommended := true;
        TempTradeSignal.Modify();
        exit(true);
    end;

    /// <summary>
    /// Expirations from the setup that are a whole number of candles of the pair timeframe, ascending, with their candle counts.
    /// </summary>
    procedure GetExpirations(CurrencyPair: Record "SMA Currency Pair"; RateAnalyzerSetup: Record "SMA Rate Analyzer Setup"; var Expirations: List of [Integer]; var StepsList: List of [Integer])
    var
        Parsed: List of [Integer];
        Part: Text;
        Minutes: Integer;
        TimeframeSeconds: Integer;
    begin
        foreach Part in RateAnalyzerSetup.GetSignalExpirations().Split(',', ';', ' ') do
            if Evaluate(Minutes, Part.Trim()) then
                Parsed.Add(Minutes);

        TimeframeSeconds := RateHelper.GetTimeframeSeconds(CurrencyPair.Timeframe);
        for Minutes := 1 to 60 do
            if Parsed.Contains(Minutes) and ((Minutes * 60) mod TimeframeSeconds = 0) then begin
                Expirations.Add(Minutes);
                StepsList.Add(Minutes * 60 div TimeframeSeconds);
            end;

        if Expirations.Count() = 0 then
            Error(NoExpirationsErr, RateAnalyzerSetup.GetSignalExpirations(), CurrencyPair.Timeframe);
    end;

    local procedure GetHour(Value: DateTime): Integer
    begin
        exit((DT2Time(Value) - 000000T) div 3600000);
    end;
}
