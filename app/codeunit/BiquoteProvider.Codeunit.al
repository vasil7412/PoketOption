/// <summary>
/// https://biquote.io/docs/
/// Public endpoint, no API key required (15,000 requests per minute per IP). Forex, metals and crypto (e.g. EURUSD, XAUUSD).
/// Each series is a rolling window: about 300 bars for 1 min and 288 bars for 5 min, newest first.
/// </summary>
codeunit 50127 "SMA Biquote Provider" implements "SMA IRate Data Provider"
{
    Access = Internal;

    var
        RateHelper: Codeunit "SMA Rate Helper";
        OhlcUrlTok: Label 'https://biquote.io/api/%1/ohlc?interval=%2&from=%3&limit=%4', Locked = true;
        ProviderNameTok: Label 'Biquote', Locked = true;
        CannotParseTimeErr: Label 'Cannot read the time ''%1'' from the Biquote response.', Comment = '%1 = value';

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
        Response: JsonObject;
        BarsToken: JsonToken;
        BarToken: JsonToken;
        Bar: JsonObject;
        OpenTimeText: Text;
        OpenTime: DateTime;
    begin
        HttpRequestMessage.Method := 'GET';
        HttpRequestMessage.SetRequestUri(StrSubstNo(OhlcUrlTok,
            CurrencyPair."Provider Symbol",
            GetInterval(CurrencyPair),
            CopyStr(Format(FromTime, 0, 9), 1, 19) + 'Z',
            MaxCount));
        Response.ReadFrom(RateHelper.SendRequest(HttpRequestMessage, ProviderNameTok));
        if not Response.Get('bars', BarsToken) then
            exit;

        // bars are newest first; the first one may be the still-open bar (isOpen = true)
        foreach BarToken in BarsToken.AsArray() do begin
            Bar := BarToken.AsObject();
            OpenTimeText := RateHelper.GetText(Bar, 'openTime');
            if not Evaluate(OpenTime, OpenTimeText, 9) then
                Error(CannotParseTimeErr, OpenTimeText);
            // the API returns the latest bars regardless of 'from', so skip what is older
            if OpenTime >= FromTime then
                RateHelper.AddCandle(TempRateCandle, CurrencyPair, OpenTime,
                    RateHelper.GetDecimal(Bar, 'open'),
                    RateHelper.GetDecimal(Bar, 'high'),
                    RateHelper.GetDecimal(Bar, 'low'),
                    RateHelper.GetDecimal(Bar, 'close'),
                    RateHelper.GetDecimal(Bar, 'tickVolume'));
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
