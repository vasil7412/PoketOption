/// <summary>
/// Builds the JSON the "SMA Rate Chart" control add-in renders.
/// Times are Unix seconds (UTC), the add-in converts them to the browser time zone.
/// </summary>
codeunit 50111 "SMA Rate Chart Mgt"
{
    Access = Internal;
    Permissions =
        tabledata "SMA Rate Candle" = r,
        tabledata "SMA Rate Forecast" = r;

    var
        RateHelper: Codeunit "SMA Rate Helper";

    procedure BuildChartData(CurrencyPair: Record "SMA Currency Pair"; ForecastMethod: Enum "SMA Forecast Method"; HorizonMin: Integer; var TempRateForecast: Record "SMA Rate Forecast" temporary): JsonObject
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        Data: JsonObject;
        FirstTime: DateTime;
        LastTime: DateTime;
        LastClose: Decimal;
    begin
        RateAnalyzerSetup.GetRecordOnce();
        Data.Add('candles', BuildCandles(CurrencyPair, RateAnalyzerSetup."Chart Candles", FirstTime, LastTime, LastClose));
        Data.Add('forecast', BuildForecast(TempRateForecast));
        Data.Add('pastForecast', BuildPastForecast(CurrencyPair, FirstTime, LastTime));
        Data.Add('info', BuildInfo(CurrencyPair, ForecastMethod, HorizonMin, LastTime, LastClose, TempRateForecast));
        exit(Data);
    end;

    procedure BuildOptions(CurrencyPair: Record "SMA Currency Pair"): JsonObject
    var
        Options: JsonObject;
    begin
        Options.Add('decimals', CurrencyPair."Price Decimals");
        Options.Add('pair', CurrencyPair.Code);
        exit(Options);
    end;

    local procedure BuildCandles(CurrencyPair: Record "SMA Currency Pair"; MaxCount: Integer; var FirstTime: DateTime; var LastTime: DateTime; var LastClose: Decimal): JsonArray
    var
        RateCandle: Record "SMA Rate Candle";
        Candles: JsonArray;
        Candle: JsonArray;
    begin
        RateCandle.SetRange("Pair Code", CurrencyPair.Code);
        RateCandle.SetRange(Timeframe, CurrencyPair.Timeframe);
        RateCandle.SetLoadFields(Open, High, Low, Close);
#pragma warning disable AA0181, AA0233
        if not RateCandle.FindLast() then
            exit(Candles);
        // step back from the newest candle to read the latest MaxCount candles in ascending order
        if MaxCount > 1 then
            RateCandle.Next(-(MaxCount - 1));
#pragma warning restore AA0181, AA0233
        FirstTime := RateCandle."Open Time";
        repeat
            Clear(Candle);
            Candle.Add(RateHelper.DateTimeToUnixSec(RateCandle."Open Time"));
            Candle.Add(RateCandle.Open);
            Candle.Add(RateCandle.High);
            Candle.Add(RateCandle.Low);
            Candle.Add(RateCandle.Close);
            Candles.Add(Candle);
            LastTime := RateCandle."Open Time";
            LastClose := RateCandle.Close;
        until RateCandle.Next() = 0;
        exit(Candles);
    end;

    local procedure BuildForecast(var TempRateForecast: Record "SMA Rate Forecast" temporary): JsonArray
    var
        Points: JsonArray;
    begin
        TempRateForecast.Reset();
        if not TempRateForecast.FindSet() then
            exit(Points);
        // the line starts at the base candle so it visually continues the price
        Points.Add(ForecastPoint(TempRateForecast."Base Time", TempRateForecast."Base Close", TempRateForecast."Base Close", TempRateForecast."Base Close"));
        repeat
            Points.Add(ForecastPoint(TempRateForecast."Target Time", TempRateForecast."Predicted Close", TempRateForecast."Lower Bound", TempRateForecast."Upper Bound"));
        until TempRateForecast.Next() = 0;
        exit(Points);
    end;

    local procedure BuildPastForecast(CurrencyPair: Record "SMA Currency Pair"; FirstTime: DateTime; LastTime: DateTime): JsonArray
    var
        RateForecast: Record "SMA Rate Forecast";
        Points: JsonArray;
        Point: JsonArray;
    begin
        if FirstTime = 0DT then
            exit(Points);
        // primary key order (base time); the add-in sorts and de-duplicates target times
        RateForecast.SetRange("Pair Code", CurrencyPair.Code);
        RateForecast.SetRange(Timeframe, CurrencyPair.Timeframe);
        RateForecast.SetRange("Horizon Step", true);
        RateForecast.SetRange("Target Time", FirstTime, LastTime);
        RateForecast.SetLoadFields("Target Time", "Predicted Close");
        if RateForecast.FindSet() then
            repeat
                Clear(Point);
                Point.Add(RateHelper.DateTimeToUnixSec(RateForecast."Target Time"));
                Point.Add(RateForecast."Predicted Close");
                Points.Add(Point);
            until RateForecast.Next() = 0;
        exit(Points);
    end;

    local procedure BuildInfo(CurrencyPair: Record "SMA Currency Pair"; ForecastMethod: Enum "SMA Forecast Method"; HorizonMin: Integer; LastTime: DateTime; LastClose: Decimal; var TempRateForecast: Record "SMA Rate Forecast" temporary): JsonObject
    var
        Info: JsonObject;
    begin
        Info.Add('pair', CurrencyPair.Code);
        Info.Add('description', CurrencyPair.Description);
        Info.Add('provider', Format(CurrencyPair.Provider));
        Info.Add('timeframe', Format(CurrencyPair.Timeframe));
        Info.Add('method', Format(ForecastMethod));
        Info.Add('horizonMin', HorizonMin);
        Info.Add('decimals', CurrencyPair."Price Decimals");
        Info.Add('lastClose', LastClose);
        if LastTime <> 0DT then
            Info.Add('lastTime', RateHelper.DateTimeToUnixSec(LastTime));
        Info.Add('hitRate', CurrencyPair.GetHitRateText());

        TempRateForecast.Reset();
        TempRateForecast.SetRange("Horizon Step", true);
        if TempRateForecast.FindFirst() then begin
            Info.Add('forecastClose', TempRateForecast."Predicted Close");
            Info.Add('lower', TempRateForecast."Lower Bound");
            Info.Add('upper', TempRateForecast."Upper Bound");
            Info.Add('targetTime', RateHelper.DateTimeToUnixSec(TempRateForecast."Target Time"));
            if TempRateForecast."Base Close" <> 0 then
                Info.Add('changePct', (TempRateForecast."Predicted Close" - TempRateForecast."Base Close") / TempRateForecast."Base Close" * 100);
        end;
        TempRateForecast.Reset();
        exit(Info);
    end;

    local procedure ForecastPoint(PointTime: DateTime; Value: Decimal; Lower: Decimal; Upper: Decimal): JsonArray
    var
        Point: JsonArray;
    begin
        Point.Add(RateHelper.DateTimeToUnixSec(PointTime));
        Point.Add(Value);
        Point.Add(Lower);
        Point.Add(Upper);
        exit(Point);
    end;
}
