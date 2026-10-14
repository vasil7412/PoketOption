/// <summary>
/// https://developers.binance.com/docs/binance-spot-api-docs/rest-api/market-data-endpoints#klinecandlestick-data
/// Public endpoint, no API key required. Crypto pairs only (e.g. BTCUSDT, ETHUSDT, EURUSDT).
/// </summary>
codeunit 50103 "SMA Binance Provider" implements "SMA IRate Data Provider"
{
    Access = Internal;

    var
        RateHelper: Codeunit "SMA Rate Helper";
        KlinesUrlTok: Label 'https://api.binance.com/api/v3/klines?symbol=%1&interval=%2&startTime=%3&limit=%4', Locked = true;
        ProviderNameTok: Label 'Binance', Locked = true;

    procedure GetDefaultSymbol(BaseCurrency: Code[10]; QuoteCurrency: Code[10]): Text[30]
    begin
        exit(CopyStr(BaseCurrency + QuoteCurrency, 1, 30));
    end;

    procedure GetMaxCandlesPerRequest(): Integer
    begin
        exit(1000);
    end;

    procedure FetchCandles(CurrencyPair: Record "SMA Currency Pair"; FromTime: DateTime; MaxCount: Integer; var TempRateCandle: Record "SMA Rate Candle" temporary)
    var
        HttpRequestMessage: HttpRequestMessage;
        ResponseArray: JsonArray;
        KlineToken: JsonToken;
        Kline: JsonArray;
        Token: JsonToken;
        OpenTime: DateTime;
        Prices: array[5] of Decimal;
        i: Integer;
    begin
        HttpRequestMessage.Method := 'GET';
        HttpRequestMessage.SetRequestUri(StrSubstNo(KlinesUrlTok,
            CurrencyPair."Provider Symbol",
            GetInterval(CurrencyPair),
            RateHelper.DateTimeToUnixMs(FromTime),
            MaxCount));
        ResponseArray.ReadFrom(RateHelper.SendRequest(HttpRequestMessage, ProviderNameTok));

        // [openTime, open, high, low, close, volume, closeTime, ...]
        foreach KlineToken in ResponseArray do begin
            Kline := KlineToken.AsArray();
            Kline.Get(0, Token);
            OpenTime := RateHelper.UnixMsToDateTime(RateHelper.TokenToBigInteger(Token));
            for i := 1 to 5 do begin
                Kline.Get(i, Token);
                Prices[i] := RateHelper.TokenToDecimal(Token);
            end;
            RateHelper.AddCandle(TempRateCandle, CurrencyPair, OpenTime, Prices[1], Prices[2], Prices[3], Prices[4], Prices[5]);
        end;
    end;

    local procedure GetInterval(CurrencyPair: Record "SMA Currency Pair"): Text
    begin
        case CurrencyPair.Timeframe of
            "SMA Rate Timeframe"::"1 Min":
                exit('1m');
            "SMA Rate Timeframe"::"5 Min":
                exit('5m');
        end;
        RateHelper.ThrowTimeframeNotSupported(CurrencyPair.Timeframe, CurrencyPair.Provider);
    end;
}
