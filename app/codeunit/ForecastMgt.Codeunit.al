codeunit 50104 "SMA Forecast Mgt"
{
    Permissions =
        tabledata "SMA Rate Candle" = r,
        tabledata "SMA Rate Forecast" = rimd;

    var
        RateHelper: Codeunit "SMA Rate Helper";
        ForecastMath: Codeunit "SMA Forecast Math";

    /// <summary>
    /// Builds a forecast of the pair on the latest stored candles into TempRateForecast (one record per future candle).
    /// </summary>
    /// <returns>False if there are not enough candles.</returns>
    procedure BuildForecast(CurrencyPair: Record "SMA Currency Pair"; ForecastMethod: Enum "SMA Forecast Method"; HorizonMin: Integer; var TempRateForecast: Record "SMA Rate Forecast" temporary): Boolean
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        ForecastContext: Codeunit "SMA Forecast Context";
        ForecastEngine: Codeunit "SMA Forecast Engine";
        Points: List of [Decimal];
        Sigmas: List of [Decimal];
        TimeframeDuration: Duration;
        BaseTime: DateTime;
        BaseClose: Decimal;
        Steps: Integer;
        Step: Integer;
    begin
        TempRateForecast.Reset();
        TempRateForecast.DeleteAll();
        RateAnalyzerSetup.GetRecordOnce();

        Steps := GetSteps(HorizonMin, CurrencyPair.Timeframe);
        // the weighted ensemble also needs the candles before the window to weight its components
        ForecastContext.Load(CurrencyPair, RateAnalyzerSetup."Lookback Candles" + RateAnalyzerSetup.GetHistoryCandles() + Steps + 1, false);
        if ForecastContext.CandleCount() < MinCandles() then
            exit(false);

        ForecastEngine.GetForecast(ForecastContext, ForecastMethod, Steps, Points, Sigmas);
        if Points.Count() < Steps then
            exit(false);

        TimeframeDuration := RateHelper.GetTimeframeDuration(CurrencyPair.Timeframe);
        BaseClose := ForecastContext.CloseAt(ForecastContext.CandleCount());
        BaseTime := ForecastContext.TimeAt(ForecastContext.CandleCount());
        for Step := 1 to Steps do begin
            TempRateForecast.Init();
            TempRateForecast."Pair Code" := CurrencyPair.Code;
            TempRateForecast.Timeframe := CurrencyPair.Timeframe;
            TempRateForecast."Base Time" := BaseTime;
            TempRateForecast.Step := Step;
            TempRateForecast."Target Time" := BaseTime + TimeframeDuration * Step;
            TempRateForecast.Method := ForecastMethod;
            TempRateForecast."Base Close" := BaseClose;
            TempRateForecast."Predicted Close" := Points.Get(Step);
            TempRateForecast."Lower Bound" := Points.Get(Step) - RateAnalyzerSetup."Band Width (Std. Dev.)" * Sigmas.Get(Step);
            TempRateForecast."Upper Bound" := Points.Get(Step) + RateAnalyzerSetup."Band Width (Std. Dev.)" * Sigmas.Get(Step);
            TempRateForecast."Horizon Step" := Step = Steps;
            TempRateForecast."Created At" := CurrentDateTime();
            TempRateForecast.Insert();
        end;
        exit(true);
    end;

    /// <summary>
    /// Stores the forecast. A forecast built earlier on the same base candle (while it was still forming) is replaced.
    /// </summary>
    procedure SaveForecast(var TempRateForecast: Record "SMA Rate Forecast" temporary)
    var
        RateForecast: Record "SMA Rate Forecast";
    begin
        TempRateForecast.Reset();
        if not TempRateForecast.FindSet() then
            exit;

        RateForecast.SetRange("Pair Code", TempRateForecast."Pair Code");
        RateForecast.SetRange(Timeframe, TempRateForecast.Timeframe);
        RateForecast.SetRange("Base Time", TempRateForecast."Base Time");
        RateForecast.DeleteAll();

        repeat
            RateForecast := TempRateForecast;
            RateForecast.Insert();
        until TempRateForecast.Next() = 0;
    end;

    /// <summary>
    /// Compares stored forecasts whose target candle is complete with the actual close price.
    /// </summary>
    procedure EvaluateForecasts(CurrencyPair: Record "SMA Currency Pair")
    var
        RateCandle: Record "SMA Rate Candle";
        TargetRateCandle: Record "SMA Rate Candle";
        RateForecast: Record "SMA Rate Forecast";
        RateForecastToUpdate: Record "SMA Rate Forecast";
        LastCompleteTime: DateTime;
    begin
        RateCandle.SetRange("Pair Code", CurrencyPair.Code);
        RateCandle.SetRange(Timeframe, CurrencyPair.Timeframe);
        RateCandle.SetRange(Complete, true);
        RateCandle.SetLoadFields("Open Time");
        if not RateCandle.FindLast() then
            exit;
        LastCompleteTime := RateCandle."Open Time";

        RateForecast.SetCurrentKey("Pair Code", Timeframe, Evaluated, "Target Time");
        RateForecast.SetRange("Pair Code", CurrencyPair.Code);
        RateForecast.SetRange(Timeframe, CurrencyPair.Timeframe);
        RateForecast.SetRange(Evaluated, false);
        RateForecast.SetRange("Target Time", 0DT, LastCompleteTime);
        if not RateForecast.FindSet() then
            exit;

        repeat
            RateForecastToUpdate := RateForecast;
            if TargetRateCandle.Get(RateForecast."Pair Code", RateForecast.Timeframe, RateForecast."Target Time") then begin
                RateForecastToUpdate."Actual Close" := TargetRateCandle.Close;
                RateForecastToUpdate."Abs. Error" := Abs(RateForecast."Predicted Close" - TargetRateCandle.Close);
                RateForecastToUpdate."Direction Hit" :=
                    ForecastMath.Sign(RateForecast."Predicted Close" - RateForecast."Base Close") =
                    ForecastMath.Sign(TargetRateCandle.Close - RateForecast."Base Close");
                RateForecastToUpdate.Evaluated := true;
                RateForecastToUpdate.Modify();
            end else
                // no candle at the target time (market closed) - the forecast cannot be evaluated
                RateForecastToUpdate.Delete();
        until RateForecast.Next() = 0;
    end;

    /// <summary>
    /// Number of candles that cover the horizon (at least one).
    /// </summary>
    procedure GetSteps(HorizonMin: Integer; Timeframe: Enum "SMA Rate Timeframe"): Integer
    var
        Steps: Integer;
    begin
        Steps := Round(HorizonMin * 60 / RateHelper.GetTimeframeSeconds(Timeframe), 1, '>');
        if Steps < 1 then
            Steps := 1;
        exit(Steps);
    end;

    procedure MinCandles(): Integer
    begin
        exit(10);
    end;
}
