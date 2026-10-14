/// <summary>
/// https://twelvedata.com/docs#time-series
/// Free plan: 800 requests per day, 8 per minute. Supports forex, crypto and stocks.
/// </summary>
codeunit 50101 "SMA Twelve Data Provider" implements "SMA IRate Data Provider"
{
    Access = Internal;

    var
        RateHelper: Codeunit "SMA Rate Helper";
        BaseUrlTok: Label 'https://api.twelvedata.com/time_series?symbol=%1&interval=%2&start_date=%3&end_date=%4&timezone=UTC&order=asc&outputsize=%5', Locked = true;
        ProviderNameTok: Label 'Twelve Data', Locked = true;
        ProviderErr: Label 'Twelve Data returned an error: %1', Comment = '%1 = error message';

    procedure GetDefaultSymbol(BaseCurrency: Code[10]; QuoteCurrency: Code[10]): Text[30]
    begin
        exit(CopyStr(BaseCurrency + '/' + QuoteCurrency, 1, 30));
    end;

    procedure GetMaxCandlesPerRequest(): Integer
    begin
        exit(1000);
    end;

    procedure FetchCandles(CurrencyPair: Record "SMA Currency Pair"; FromTime: DateTime; MaxCount: Integer; var TempRateCandle: Record "SMA Rate Candle" temporary)
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        Uri: Codeunit Uri;
        HttpRequestMessage: HttpRequestMessage;
        ResponseJson: JsonObject;
        ValuesToken: JsonToken;
        ValueToken: JsonToken;
        ValueObject: JsonObject;
        PlainUrl: Text;
        SecretUrl: SecretText;
        ToTime: DateTime;
    begin
        RateAnalyzerSetup.GetRecordOnce();
        // Twelve Data returns the newest values of a range first, so the window is bounded to page forward reliably
        ToTime := FromTime + RateHelper.GetTimeframeDuration(CurrencyPair.Timeframe) * MaxCount;
        PlainUrl := StrSubstNo(BaseUrlTok,
            Uri.EscapeDataString(CurrencyPair."Provider Symbol"),
            GetInterval(CurrencyPair),
            Uri.EscapeDataString(RateHelper.FormatUtcSql(FromTime)),
            Uri.EscapeDataString(RateHelper.FormatUtcSql(ToTime)),
            MaxCount);
        SecretUrl := SecretStrSubstNo('%1&apikey=%2', PlainUrl, RateAnalyzerSetup.GetTwelveDataApiKey());

        HttpRequestMessage.Method := 'GET';
        HttpRequestMessage.SetSecretRequestUri(SecretUrl);
        ResponseJson.ReadFrom(RateHelper.SendRequest(HttpRequestMessage, ProviderNameTok));

        if RateHelper.GetText(ResponseJson, 'status') = 'error' then begin
            // An empty window (weekend, holiday) is reported as an error by Twelve Data
            if StrPos(LowerCase(RateHelper.GetText(ResponseJson, 'message')), 'no data') > 0 then
                exit;
            Error(ProviderErr, RateHelper.GetText(ResponseJson, 'message'));
        end;

        if not ResponseJson.Get('values', ValuesToken) then
            exit;
        foreach ValueToken in ValuesToken.AsArray() do begin
            ValueObject := ValueToken.AsObject();
            RateHelper.AddCandle(TempRateCandle, CurrencyPair,
                RateHelper.ParseUtcSql(RateHelper.GetText(ValueObject, 'datetime')),
                RateHelper.GetDecimal(ValueObject, 'open'),
                RateHelper.GetDecimal(ValueObject, 'high'),
                RateHelper.GetDecimal(ValueObject, 'low'),
                RateHelper.GetDecimal(ValueObject, 'close'),
                RateHelper.GetDecimal(ValueObject, 'volume'));
        end;
    end;

    local procedure GetInterval(CurrencyPair: Record "SMA Currency Pair"): Text
    begin
        case CurrencyPair.Timeframe of
            "SMA Rate Timeframe"::"1 Min":
                exit('1min');
            "SMA Rate Timeframe"::"5 Min":
                exit('5min');
        end;
        RateHelper.ThrowTimeframeNotSupported(CurrencyPair.Timeframe, CurrencyPair.Provider);
    end;
}
