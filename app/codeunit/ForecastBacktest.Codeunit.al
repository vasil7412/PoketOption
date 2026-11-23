/// <summary>
/// Replays every forecast method over the stored history and measures how often it guessed the direction
/// and how its error compares to the naive "no change" forecast.
/// </summary>
codeunit 50108 "SMA Forecast Backtest"
{
    Permissions =
        tabledata "SMA Rate Candle" = r,
        tabledata "SMA Backtest Result" = ri;

    var
        ForecastMath: Codeunit "SMA Forecast Math";
        NotEnoughCandlesErr: Label 'There are only %1 candles of %2 %3. At least %4 are needed for the backtest. Load more history first.', Comment = '%1 = candles, %2 = pair, %3 = timeframe, %4 = required';
        ProgressMsg: Label 'Backtesting #1####################\Progress @2@@@@@@@@@@', Comment = '#1 = method, @2 = progress';

    procedure RunBacktest(CurrencyPair: Record "SMA Currency Pair"; HorizonMin: Integer)
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        ForecastContext: Codeunit "SMA Forecast Context";
        ForecastMgt: Codeunit "SMA Forecast Mgt";
        ForecastMethod: Enum "SMA Forecast Method";
        Ordinal: Integer;
        Lookback: Integer;
        Steps: Integer;
    begin
        RateAnalyzerSetup.GetRecordOnce();
        Lookback := RateAnalyzerSetup."Lookback Candles";
        Steps := ForecastMgt.GetSteps(HorizonMin, CurrencyPair.Timeframe);

        // the forming candle would distort the result
        ForecastContext.Load(CurrencyPair, RateAnalyzerSetup."Backtest Candles", true);
        if ForecastContext.CandleCount() < Lookback + Steps + 10 then
            Error(NotEnoughCandlesErr, ForecastContext.CandleCount(), CurrencyPair.Code, CurrencyPair.Timeframe, Lookback + Steps + 10);

        // one context for all methods: the ensembles reuse the cached forecasts of their components
        foreach Ordinal in Enum::"SMA Forecast Method".Ordinals() do begin
            ForecastMethod := Enum::"SMA Forecast Method".FromInteger(Ordinal);
            TestMethod(CurrencyPair, ForecastMethod, HorizonMin, Lookback, Steps, ForecastContext);
        end;
    end;

    local procedure TestMethod(CurrencyPair: Record "SMA Currency Pair"; ForecastMethod: Enum "SMA Forecast Method"; HorizonMin: Integer; Lookback: Integer; Steps: Integer; var ForecastContext: Codeunit "SMA Forecast Context")
    var
        BacktestResult: Record "SMA Backtest Result";
        ForecastEngine: Codeunit "SMA Forecast Engine";
        Window: Dialog;
        Points: List of [Decimal];
        Sigmas: List of [Decimal];
        BaseClose: Decimal;
        ActualClose: Decimal;
        PredictedClose: Decimal;
        SumAbsError: Decimal;
        SumNaiveError: Decimal;
        HasForecast: Boolean;
        Samples: Integer;
        SignalSamples: Integer;
        Hits: Integer;
        Total: Integer;
        i: Integer;
    begin
        Total := ForecastContext.CandleCount() - Steps - Lookback + 1;
        if GuiAllowed() then begin
            Window.Open(ProgressMsg);
            Window.Update(1, Format(ForecastMethod));
        end;

        for i := Lookback to ForecastContext.CandleCount() - Steps do begin
            // across a gap the candle Steps later is not Steps timeframes later: such an outcome is not tested
            HasForecast := false;
            if ForecastContext.IsContinuous(i, i + Steps) then begin
                ForecastContext.SetPosition(i);
                ForecastEngine.GetForecast(ForecastContext, ForecastMethod, Steps, Points, Sigmas);
                HasForecast := Points.Count() >= Steps;
            end;
            if HasForecast then begin
                BaseClose := ForecastContext.CloseAt(i);
                ActualClose := ForecastContext.CloseAt(i + Steps);
                PredictedClose := Points.Get(Steps);
                // a forecast without a direction is no trade, an unchanged price is a refund: neither counts for the hit rate
                if (ForecastMath.Sign(PredictedClose - BaseClose) <> 0) and (ForecastMath.Sign(ActualClose - BaseClose) <> 0) then begin
                    SignalSamples += 1;
                    if ForecastMath.Sign(PredictedClose - BaseClose) = ForecastMath.Sign(ActualClose - BaseClose) then
                        Hits += 1;
                end;
                SumAbsError += Abs(PredictedClose - ActualClose);
                SumNaiveError += Abs(BaseClose - ActualClose);
                Samples += 1;
            end;
            if GuiAllowed() and (i mod 100 = 0) then
                Window.Update(2, Round((i - Lookback + 1) / Total * 10000, 1));
        end;
        if GuiAllowed() then
            Window.Close();

        BacktestResult.Init();
        BacktestResult."Pair Code" := CurrencyPair.Code;
        BacktestResult.Timeframe := CurrencyPair.Timeframe;
        BacktestResult.Method := ForecastMethod;
        BacktestResult."Horizon (Min)" := HorizonMin;
        BacktestResult."Lookback Candles" := Lookback;
        BacktestResult."Run At" := CurrentDateTime();
        BacktestResult."From Time" := ForecastContext.TimeAt(1);
        BacktestResult."To Time" := ForecastContext.TimeAt(ForecastContext.CandleCount());
        BacktestResult.Samples := Samples;
        BacktestResult."Signal Samples" := SignalSamples;
        BacktestResult."Direction Hits" := Hits;
        if SignalSamples > 0 then
            BacktestResult."Hit Rate %" := Round(Hits / SignalSamples * 100, 0.01);
        if Samples > 0 then begin
            BacktestResult.MAE := SumAbsError / Samples;
            BacktestResult."Naive MAE" := SumNaiveError / Samples;
        end;
        if BacktestResult."Naive MAE" <> 0 then
            BacktestResult."Skill %" := Round((1 - BacktestResult.MAE / BacktestResult."Naive MAE") * 100, 0.01);
        BacktestResult.Insert();
    end;
}
