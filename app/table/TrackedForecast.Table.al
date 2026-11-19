/// <summary>
/// Live forecast journal: every few minutes the job queue records the forecast of every method for every signal expiration,
/// and after the expiration compares it with the actual price. The results feed the live method ranking.
/// </summary>
table 50106 "SMA Tracked Forecast"
{
    Caption = 'Tracked Forecast';
    DataClassification = CustomerContent;
    DrillDownPageId = "SMA Tracked Forecasts";
    LookupPageId = "SMA Tracked Forecasts";

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
        field(3; "Base Time"; DateTime)
        {
            Caption = 'Base Time';
            ToolTip = 'Specifies the open time of the last complete candle the forecast is based on.';
        }
        field(4; Method; Enum "SMA Forecast Method")
        {
            Caption = 'Method';
            ToolTip = 'Specifies the forecast method.';
        }
        field(5; "Expiration (Min)"; Integer)
        {
            Caption = 'Expiration (Min)';
            ToolTip = 'Specifies how many minutes after the close of the base candle the forecast is checked.';
        }
        field(6; Steps; Integer)
        {
            Caption = 'Steps';
            ToolTip = 'Specifies how many candles the expiration covers.';
        }
        field(7; "Target Time"; DateTime)
        {
            Caption = 'Target Time';
            ToolTip = 'Specifies the open time of the candle whose close price is compared with the forecast.';
        }
        field(8; "Base Close"; Decimal)
        {
            Caption = 'Base Close';
            ToolTip = 'Specifies the close price of the base candle.';
            DecimalPlaces = 0 : 8;
        }
        field(9; "Predicted Close"; Decimal)
        {
            Caption = 'Predicted Close';
            ToolTip = 'Specifies the predicted close price of the target candle.';
            DecimalPlaces = 0 : 8;
        }
        field(10; Direction; Enum "SMA Trade Direction")
        {
            Caption = 'Direction';
            ToolTip = 'Specifies the predicted direction.';
        }
        field(11; "Created At"; DateTime)
        {
            Caption = 'Created At';
            ToolTip = 'Specifies when the forecast was recorded.';
        }
        field(20; Evaluated; Boolean)
        {
            Caption = 'Evaluated';
            ToolTip = 'Specifies whether the forecast has been compared with the actual price.';
        }
        field(21; "Actual Close"; Decimal)
        {
            Caption = 'Actual Close';
            ToolTip = 'Specifies the actual close price of the target candle.';
            DecimalPlaces = 0 : 8;
        }
        field(22; "Actual Direction"; Enum "SMA Trade Direction")
        {
            Caption = 'Actual Direction';
            ToolTip = 'Specifies the actual direction of the price move. No signal means the price did not change (a refund).';
        }
        field(23; Counted; Boolean)
        {
            Caption = 'Counted';
            ToolTip = 'Specifies whether the forecast counts for the ranking: it predicted a direction and the price actually changed.';
        }
        field(24; Hit; Boolean)
        {
            Caption = 'Hit';
            ToolTip = 'Specifies whether the predicted direction was correct.';
        }
        field(25; "Evaluated At"; DateTime)
        {
            Caption = 'Evaluated At';
            ToolTip = 'Specifies when the forecast was compared with the actual price.';
        }
    }

    keys
    {
        key(PK; "Pair Code", Timeframe, "Base Time", Method, "Expiration (Min)")
        {
            Clustered = true;
        }
        key(Evaluation; "Pair Code", Timeframe, Evaluated, "Target Time") { }
        key(Created; "Created At") { }
    }
}
