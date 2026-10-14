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
        ForecastMgt: Codeunit "SMA Forecast Mgt";
        ForecastMethod: Enum "SMA Forecast Method";
        Closes: List of [Decimal];
        Times: List of [DateTime];
        Ordinal: Integer;
        Lookback: Integer;
        Steps: Integer;
    begin
        RateAnalyzerSetup.GetRecordOnce();
        Lookback := RateAnalyzerSetup."Lookback Candles";
        Steps := ForecastMgt.GetSteps(HorizonMin, CurrencyPair.Timeframe);

        LoadHistory(CurrencyPair, RateAnalyzerSetup."Backtest Candles", Closes, Times);
        if Closes.Count() < Lookback + Steps + 10 then
            Error(NotEnoughCandlesErr, Closes.Count(), CurrencyPair.Code, CurrencyPair.Timeframe, Lookback + Steps + 10);

        foreach Ordinal in Enum::"SMA Forecast Method".Ordinals() do begin
            ForecastMethod := Enum::"SMA Forecast Method".FromInteger(Ordinal);
            TestMethod(CurrencyPair, ForecastMethod, HorizonMin, Lookback, Steps, Closes, Times);
        end;
    end;

    local procedure TestMethod(CurrencyPair: Record "SMA Currency Pair"; ForecastMethod: Enum "SMA Forecast Method"; HorizonMin: Integer; Lookback: Integer; Steps: Integer; Closes: List of [Decimal]; Times: List of [DateTime])
    var
        BacktestResult: Record "SMA Backtest Result";
        ForecastImpl: Interface "SMA IForecast Method";
        Window: Dialog;
        Points: List of [Decimal];
        Sigmas: List of [Decimal];
        BaseClose: Decimal;
        ActualClose: Decimal;
        PredictedClose: Decimal;
        SumAbsError: Decimal;
        SumNaiveError: Decimal;
        Samples: Integer;
        Hits: Integer;
        Total: Integer;
        i: Integer;
    begin
        ForecastImpl := ForecastMethod;
        Total := Closes.Count() - Steps - Lookback + 1;
        if GuiAllowed() then begin
            Window.Open(ProgressMsg);
            Window.Update(1, Format(ForecastMethod));
        end;

        for i := Lookback to Closes.Count() - Steps do begin
            ForecastImpl.Forecast(Closes.GetRange(i - Lookback + 1, Lookback), Steps, Points, Sigmas);
            BaseClose := Closes.Get(i);
            ActualClose := Closes.Get(i + Steps);
            PredictedClose := Points.Get(Steps);
            if ForecastMath.Sign(PredictedClose - BaseClose) = ForecastMath.Sign(ActualClose - BaseClose) then
                Hits += 1;
            SumAbsError += Abs(PredictedClose - ActualClose);
            SumNaiveError += Abs(BaseClose - ActualClose);
            Samples += 1;
            if GuiAllowed() and (Samples mod 100 = 0) then
                Window.Update(2, Round(Samples / Total * 10000, 1));
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
        BacktestResult."From Time" := Times.Get(1);
        BacktestResult."To Time" := Times.Get(Times.Count());
        BacktestResult.Samples := Samples;
        BacktestResult."Direction Hits" := Hits;
        if Samples > 0 then begin
            BacktestResult."Hit Rate %" := Round(Hits / Samples * 100, 0.01);
            BacktestResult.MAE := SumAbsError / Samples;
            BacktestResult."Naive MAE" := SumNaiveError / Samples;
        end;
        if BacktestResult."Naive MAE" <> 0 then
            BacktestResult."Skill %" := Round((1 - BacktestResult.MAE / BacktestResult."Naive MAE") * 100, 0.01);
        BacktestResult.Insert();
    end;

    local procedure LoadHistory(CurrencyPair: Record "SMA Currency Pair"; MaxCount: Integer; var Closes: List of [Decimal]; var Times: List of [DateTime])
    var
        RateCandle: Record "SMA Rate Candle";
    begin
        RateCandle.SetRange("Pair Code", CurrencyPair.Code);
        RateCandle.SetRange(Timeframe, CurrencyPair.Timeframe);
        // the forming candle would distort the result
        RateCandle.SetRange(Complete, true);
        RateCandle.SetLoadFields(Close);
#pragma warning disable AA0181, AA0233
        if not RateCandle.FindLast() then
            exit;
        // step back from the newest candle to read the latest MaxCount candles in ascending order
        if MaxCount > 1 then
            RateCandle.Next(-(MaxCount - 1));
#pragma warning restore AA0181, AA0233
        repeat
            Closes.Add(RateCandle.Close);
            Times.Add(RateCandle."Open Time");
        until RateCandle.Next() = 0;
    end;
}
