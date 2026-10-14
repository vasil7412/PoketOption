table 50102 "SMA Rate Candle"
{
    Caption = 'Rate Candle';
    DataClassification = CustomerContent;
    DrillDownPageId = "SMA Rate Candles";
    LookupPageId = "SMA Rate Candles";

    fields
    {
        field(1; "Pair Code"; Code[20])
        {
            Caption = 'Pair Code';
            ToolTip = 'Specifies the currency pair.';
            TableRelation = "SMA Currency Pair";
        }
        field(2; Timeframe; Enum "SMA Rate Timeframe")
        {
            Caption = 'Timeframe';
            ToolTip = 'Specifies the candle timeframe.';
        }
        field(3; "Open Time"; DateTime)
        {
            Caption = 'Open Time';
            ToolTip = 'Specifies when the candle period starts.';
        }
        field(10; Open; Decimal)
        {
            Caption = 'Open';
            ToolTip = 'Specifies the first price of the candle period.';
            DecimalPlaces = 0 : 8;
        }
        field(11; High; Decimal)
        {
            Caption = 'High';
            ToolTip = 'Specifies the highest price of the candle period.';
            DecimalPlaces = 0 : 8;
        }
        field(12; Low; Decimal)
        {
            Caption = 'Low';
            ToolTip = 'Specifies the lowest price of the candle period.';
            DecimalPlaces = 0 : 8;
        }
        field(13; Close; Decimal)
        {
            Caption = 'Close';
            ToolTip = 'Specifies the last price of the candle period.';
            DecimalPlaces = 0 : 8;
        }
        field(14; Volume; Decimal)
        {
            Caption = 'Volume';
            ToolTip = 'Specifies the traded volume or tick count of the candle period, if the provider returns it.';
            DecimalPlaces = 0 : 8;
        }
        field(15; Complete; Boolean)
        {
            Caption = 'Complete';
            ToolTip = 'Specifies whether the candle period is finished. The latest candle is usually still forming.';
        }
    }

    keys
    {
        key(PK; "Pair Code", Timeframe, "Open Time")
        {
            Clustered = true;
        }
    }
}
