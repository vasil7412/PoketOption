codeunit 50110 "SMA Rate Helper"
{
    Access = Internal;

    var
        RequestFailedErr: Label 'The request to %1 failed with status %2 %3: %4', Comment = '%1 = provider, %2 = status code, %3 = reason, %4 = response body';
        TimeframeNotSupportedErr: Label 'The timeframe %1 is not supported by the provider %2.', Comment = '%1 = timeframe, %2 = provider';
        CannotParseNumberErr: Label 'Cannot read the number ''%1'' from the provider response.', Comment = '%1 = value';

    procedure GetEpoch(): DateTime
    var
        Epoch: DateTime;
    begin
        Evaluate(Epoch, '1970-01-01T00:00:00Z', 9);
        exit(Epoch);
    end;

    procedure UnixMsToDateTime(UnixMs: BigInteger): DateTime
    var
        Offset: Duration;
    begin
        Offset := UnixMs;
        exit(GetEpoch() + Offset);
    end;

    procedure UnixSecToDateTime(UnixSec: BigInteger): DateTime
    begin
        exit(UnixMsToDateTime(UnixSec * 1000));
    end;

    procedure DateTimeToUnixMs(Value: DateTime): BigInteger
    var
        Offset: Duration;
        Result: BigInteger;
    begin
        Offset := Value - GetEpoch();
        Result := Offset;
        exit(Result);
    end;

    procedure DateTimeToUnixSec(Value: DateTime): BigInteger
    begin
        exit(DateTimeToUnixMs(Value) div 1000);
    end;

    /// <summary>
    /// Formats a DateTime as 'yyyy-MM-dd HH:mm:ss' in UTC.
    /// </summary>
    procedure FormatUtcSql(Value: DateTime): Text
    begin
        exit(ConvertStr(CopyStr(Format(Value, 0, 9), 1, 19), 'T', ' '));
    end;

    /// <summary>
    /// Parses 'yyyy-MM-dd HH:mm:ss' (UTC) into a DateTime.
    /// </summary>
    procedure ParseUtcSql(Value: Text): DateTime
    var
        Result: DateTime;
    begin
        Evaluate(Result, ConvertStr(Value, ' ', 'T') + 'Z', 9);
        exit(Result);
    end;

    procedure GetTimeframeSeconds(Timeframe: Enum "SMA Rate Timeframe"): Integer
    begin
        exit(Timeframe.AsInteger());
    end;

    procedure GetTimeframeDuration(Timeframe: Enum "SMA Rate Timeframe"): Duration
    begin
        exit(Timeframe.AsInteger() * 1000);
    end;

    procedure ThrowTimeframeNotSupported(Timeframe: Enum "SMA Rate Timeframe"; Provider: Enum "SMA Rate Data Provider")
    begin
        Error(TimeframeNotSupportedErr, Timeframe, Provider);
    end;

    procedure SendRequest(var HttpRequestMessage: HttpRequestMessage; ProviderName: Text): Text
    var
        HttpClient: HttpClient;
        HttpResponseMessage: HttpResponseMessage;
        ResponseText: Text;
    begin
        HttpClient.Timeout := 30000;
        HttpClient.Send(HttpRequestMessage, HttpResponseMessage);
        HttpResponseMessage.Content.ReadAs(ResponseText);
        if not HttpResponseMessage.IsSuccessStatusCode() then
            Error(RequestFailedErr, ProviderName, HttpResponseMessage.HttpStatusCode(), HttpResponseMessage.ReasonPhrase(), CopyStr(ResponseText, 1, 500));
        exit(ResponseText);
    end;

    procedure GetText(JsonObject: JsonObject; PropertyName: Text): Text
    var
        JsonToken: JsonToken;
    begin
        if not JsonObject.Get(PropertyName, JsonToken) then
            exit('');
        if not JsonToken.IsValue() then
            exit('');
        if JsonToken.AsValue().IsNull() then
            exit('');
        exit(JsonToken.AsValue().AsText());
    end;

    procedure GetDecimal(JsonObject: JsonObject; PropertyName: Text): Decimal
    var
        JsonToken: JsonToken;
    begin
        if not JsonObject.Get(PropertyName, JsonToken) then
            exit(0);
        exit(TokenToDecimal(JsonToken));
    end;

    /// <summary>
    /// Reads a decimal from a JSON token that holds either a number or a numeric string (providers send prices as strings).
    /// </summary>
    procedure TokenToDecimal(JsonToken: JsonToken): Decimal
    var
        Result: Decimal;
        ValueText: Text;
    begin
        if not JsonToken.IsValue() then
            exit(0);
        if JsonToken.AsValue().IsNull() then
            exit(0);
        ValueText := JsonToken.AsValue().AsText();
        if ValueText = '' then
            exit(0);
        if not Evaluate(Result, ValueText, 9) then
            Error(CannotParseNumberErr, ValueText);
        exit(Result);
    end;

    procedure TokenToBigInteger(JsonToken: JsonToken): BigInteger
    var
        Result: BigInteger;
        ValueText: Text;
    begin
        ValueText := JsonToken.AsValue().AsText();
        if StrPos(ValueText, '.') > 0 then
            ValueText := CopyStr(ValueText, 1, StrPos(ValueText, '.') - 1);
        if not Evaluate(Result, ValueText, 9) then
            Error(CannotParseNumberErr, ValueText);
        exit(Result);
    end;

    procedure AddCandle(var TempRateCandle: Record "SMA Rate Candle" temporary; CurrencyPair: Record "SMA Currency Pair"; OpenTime: DateTime; OpenPrice: Decimal; HighPrice: Decimal; LowPrice: Decimal; ClosePrice: Decimal; Volume: Decimal)
    begin
        TempRateCandle.Init();
        TempRateCandle."Pair Code" := CurrencyPair.Code;
        TempRateCandle.Timeframe := CurrencyPair.Timeframe;
        TempRateCandle."Open Time" := OpenTime;
        TempRateCandle.Open := OpenPrice;
        TempRateCandle.High := HighPrice;
        TempRateCandle.Low := LowPrice;
        TempRateCandle.Close := ClosePrice;
        TempRateCandle.Volume := Volume;
        if not TempRateCandle.Insert() then
            TempRateCandle.Modify();
    end;
}
