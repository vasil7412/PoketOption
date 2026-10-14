/// <summary>
/// https://developer.oanda.com/rest-live-v20/instrument-ep/
/// A free practice (demo) account gives an API token with real-time forex prices.
/// </summary>
codeunit 50102 "SMA OANDA Provider" implements "SMA IRate Data Provider"
{
    Access = Internal;

    var
        RateHelper: Codeunit "SMA Rate Helper";
        CandlesUrlTok: Label '%1/v3/instruments/%2/candles?granularity=%3&price=M&from=%4&count=%5', Locked = true;
        PracticeUrlTok: Label 'https://api-fxpractice.oanda.com', Locked = true;
        LiveUrlTok: Label 'https://api-fxtrade.oanda.com', Locked = true;
        ProviderNameTok: Label 'OANDA', Locked = true;

    procedure GetDefaultSymbol(BaseCurrency: Code[10]; QuoteCurrency: Code[10]): Text[30]
    begin
        exit(CopyStr(BaseCurrency + '_' + QuoteCurrency, 1, 30));
    end;

    procedure GetMaxCandlesPerRequest(): Integer
    begin
        exit(5000);
    end;

    procedure FetchCandles(CurrencyPair: Record "SMA Currency Pair"; FromTime: DateTime; MaxCount: Integer; var TempRateCandle: Record "SMA Rate Candle" temporary)
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        HttpRequestMessage: HttpRequestMessage;
        HttpHeaders: HttpHeaders;
        ResponseJson: JsonObject;
        CandlesToken: JsonToken;
        CandleToken: JsonToken;
        CandleObject: JsonObject;
        MidToken: JsonToken;
        MidObject: JsonObject;
        TimeToken: JsonToken;
    begin
        RateAnalyzerSetup.GetRecordOnce();
        HttpRequestMessage.Method := 'GET';
        HttpRequestMessage.SetRequestUri(StrSubstNo(CandlesUrlTok,
            GetBaseUrl(RateAnalyzerSetup),
            CurrencyPair."Provider Symbol",
            GetGranularity(CurrencyPair),
            RateHelper.DateTimeToUnixSec(FromTime),
            MaxCount));
        HttpRequestMessage.GetHeaders(HttpHeaders);
        HttpHeaders.Add('Authorization', SecretStrSubstNo('Bearer %1', RateAnalyzerSetup.GetOANDAToken()));
        HttpHeaders.Add('Accept-Datetime-Format', 'UNIX');

        ResponseJson.ReadFrom(RateHelper.SendRequest(HttpRequestMessage, ProviderNameTok));
        if not ResponseJson.Get('candles', CandlesToken) then
            exit;

        foreach CandleToken in CandlesToken.AsArray() do begin
            CandleObject := CandleToken.AsObject();
            CandleObject.Get('time', TimeToken);
            CandleObject.Get('mid', MidToken);
            MidObject := MidToken.AsObject();
            RateHelper.AddCandle(TempRateCandle, CurrencyPair,
                RateHelper.UnixSecToDateTime(RateHelper.TokenToBigInteger(TimeToken)),
                RateHelper.GetDecimal(MidObject, 'o'),
                RateHelper.GetDecimal(MidObject, 'h'),
                RateHelper.GetDecimal(MidObject, 'l'),
                RateHelper.GetDecimal(MidObject, 'c'),
                RateHelper.GetDecimal(CandleObject, 'volume'));
        end;
    end;

    local procedure GetBaseUrl(RateAnalyzerSetup: Record "SMA Rate Analyzer Setup"): Text
    begin
        if RateAnalyzerSetup."OANDA Environment" = "SMA OANDA Environment"::Live then
            exit(LiveUrlTok);
        exit(PracticeUrlTok);
    end;

    local procedure GetGranularity(CurrencyPair: Record "SMA Currency Pair"): Text
    begin
        case CurrencyPair.Timeframe of
            "SMA Rate Timeframe"::"15 Sec":
                exit('S15');
            "SMA Rate Timeframe"::"30 Sec":
                exit('S30');
            "SMA Rate Timeframe"::"1 Min":
                exit('M1');
            "SMA Rate Timeframe"::"5 Min":
                exit('M5');
        end;
        RateHelper.ThrowTimeframeNotSupported(CurrencyPair.Timeframe, CurrencyPair.Provider);
    end;
}
