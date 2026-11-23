/// <summary>
/// One-click cleanup of the stored data and the setup: fills empty setup fields with their defaults,
/// sets Skip Weekend Data on every pair by its provider and deletes the synthetic weekend candles
/// (and the forecasts built on them) of the pairs that skip weekends.
/// </summary>
codeunit 50129 "SMA Data Maintenance"
{
    Permissions =
        tabledata "SMA Rate Analyzer Setup" = rm,
        tabledata "SMA Currency Pair" = rm,
        tabledata "SMA Rate Candle" = rd,
        tabledata "SMA Rate Forecast" = rd,
        tabledata "SMA Tracked Forecast" = rd;

    var
        RateHelper: Codeunit "SMA Rate Helper";

    /// <summary>
    /// Runs all steps. Returns the counts for the result message.
    /// </summary>
    procedure FillParameters(var SetupFieldsFilled: Integer; var PairsUpdated: Integer; var CandlesDeleted: Integer; var ForecastsDeleted: Integer)
    var
        CurrencyPair: Record "SMA Currency Pair";
    begin
        SetupFieldsFilled := FillSetupDefaults();
        if CurrencyPair.FindSet(true) then
            repeat
                if CurrencyPair."Skip Weekend Data" <> CurrencyPair.GetDefaultSkipWeekend() then begin
                    CurrencyPair."Skip Weekend Data" := CurrencyPair.GetDefaultSkipWeekend();
                    CurrencyPair.Modify();
                    PairsUpdated += 1;
                end;
                if CurrencyPair."Skip Weekend Data" then begin
                    CandlesDeleted += DeleteWeekendCandles(CurrencyPair);
                    ForecastsDeleted += DeleteWeekendForecasts(CurrencyPair);
                end;
            until CurrencyPair.Next() = 0;
    end;

    /// <summary>
    /// Fills every empty (zero or blank) number and text field of the setup with its initial value.
    /// Options, enums and booleans are kept, because their first value is a valid choice.
    /// </summary>
    procedure FillSetupDefaults(): Integer
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        TempDefaultSetup: Record "SMA Rate Analyzer Setup" temporary;
        SetupRecordRef: RecordRef;
        DefaultRecordRef: RecordRef;
        SetupFieldRef: FieldRef;
        DefaultFieldRef: FieldRef;
        FilledCount: Integer;
        i: Integer;
    begin
        RateAnalyzerSetup.InsertIfNotExists();
        TempDefaultSetup.Init();
        SetupRecordRef.GetTable(RateAnalyzerSetup);
        DefaultRecordRef.GetTable(TempDefaultSetup);
        for i := 1 to SetupRecordRef.FieldCount() do begin
            SetupFieldRef := SetupRecordRef.FieldIndex(i);
            DefaultFieldRef := DefaultRecordRef.Field(SetupFieldRef.Number());
            if (SetupFieldRef.Class() = FieldClass::Normal) and (SetupFieldRef.Number() <> RateAnalyzerSetup.FieldNo("Primary Key")) then
                if IsEmptyValue(SetupFieldRef) and not IsEmptyValue(DefaultFieldRef) then begin
                    SetupFieldRef.Value := DefaultFieldRef.Value();
                    FilledCount += 1;
                end;
        end;
        if FilledCount > 0 then
            SetupRecordRef.Modify();
        exit(FilledCount);
    end;

    local procedure IsEmptyValue(FieldRef: FieldRef): Boolean
    var
        IntegerValue: Integer;
        DecimalValue: Decimal;
        TextValue: Text;
    begin
        case FieldRef.Type() of
            FieldType::Integer:
                begin
                    IntegerValue := FieldRef.Value();
                    exit(IntegerValue = 0);
                end;
            FieldType::Decimal:
                begin
                    DecimalValue := FieldRef.Value();
                    exit(DecimalValue = 0);
                end;
            FieldType::Text, FieldType::Code:
                begin
                    TextValue := FieldRef.Value();
                    exit(TextValue = '');
                end;
        end;
        exit(false);
    end;

    local procedure DeleteWeekendCandles(CurrencyPair: Record "SMA Currency Pair"): Integer
    var
        RateCandle: Record "SMA Rate Candle";
        RateCandleToDelete: Record "SMA Rate Candle";
        DeletedCount: Integer;
    begin
        RateCandle.SetRange("Pair Code", CurrencyPair.Code);
        RateCandle.SetLoadFields("Pair Code", Timeframe, "Open Time");
        if RateCandle.FindSet() then
            repeat
                if RateHelper.IsForexWeekend(RateCandle."Open Time") then begin
                    RateCandleToDelete := RateCandle;
                    RateCandleToDelete.Delete();
                    DeletedCount += 1;
                end;
            until RateCandle.Next() = 0;
        exit(DeletedCount);
    end;

    local procedure DeleteWeekendForecasts(CurrencyPair: Record "SMA Currency Pair"): Integer
    var
        RateForecast: Record "SMA Rate Forecast";
        RateForecastToDelete: Record "SMA Rate Forecast";
        TrackedForecast: Record "SMA Tracked Forecast";
        TrackedForecastToDelete: Record "SMA Tracked Forecast";
        DeletedCount: Integer;
    begin
        RateForecast.SetRange("Pair Code", CurrencyPair.Code);
        if RateForecast.FindSet() then
            repeat
                if RateHelper.IsForexWeekend(RateForecast."Base Time") then begin
                    RateForecastToDelete := RateForecast;
                    RateForecastToDelete.Delete();
                    DeletedCount += 1;
                end;
            until RateForecast.Next() = 0;

        TrackedForecast.SetRange("Pair Code", CurrencyPair.Code);
        if TrackedForecast.FindSet() then
            repeat
                if RateHelper.IsForexWeekend(TrackedForecast."Base Time") then begin
                    TrackedForecastToDelete := TrackedForecast;
                    TrackedForecastToDelete.Delete();
                    DeletedCount += 1;
                end;
            until TrackedForecast.Next() = 0;
        exit(DeletedCount);
    end;
}
