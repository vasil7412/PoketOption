table 50104 "SMA Backtest Result"
{
    Caption = 'Backtest Result';
    DataClassification = CustomerContent;
    DrillDownPageId = "SMA Backtest Results";
    LookupPageId = "SMA Backtest Results";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            ToolTip = 'Specifies the number of the entry.';
            AutoIncrement = true;
        }
        field(2; "Pair Code"; Code[20])
        {
            Caption = 'Pair Code';
            ToolTip = 'Specifies the currency pair.';
            TableRelation = "SMA Currency Pair";
        }
        field(3; Timeframe; Enum "SMA Rate Timeframe")
        {
            Caption = 'Timeframe';
            ToolTip = 'Specifies the candle timeframe.';
        }
        field(4; Method; Enum "SMA Forecast Method")
        {
            Caption = 'Method';
            ToolTip = 'Specifies the tested forecast method.';
        }
        field(5; "Horizon (Min)"; Integer)
        {
            Caption = 'Horizon (Min)';
            ToolTip = 'Specifies the tested forecast horizon in minutes.';
        }
        field(6; "Lookback Candles"; Integer)
        {
            Caption = 'Lookback Candles';
            ToolTip = 'Specifies how many candles every tested forecast was based on.';
        }
        field(7; "Run At"; DateTime)
        {
            Caption = 'Run At';
            ToolTip = 'Specifies when the backtest was run.';
        }
        field(8; "From Time"; DateTime)
        {
            Caption = 'From Time';
            ToolTip = 'Specifies the open time of the first candle used in the backtest.';
        }
        field(9; "To Time"; DateTime)
        {
            Caption = 'To Time';
            ToolTip = 'Specifies the open time of the last candle used in the backtest.';
        }
        field(10; Samples; Integer)
        {
            Caption = 'Samples';
            ToolTip = 'Specifies how many forecasts were tested.';
        }
        field(11; "Direction Hits"; Integer)
        {
            Caption = 'Direction Hits';
            ToolTip = 'Specifies how many tested forecasts predicted the price direction correctly.';
        }
        field(12; "Hit Rate %"; Decimal)
        {
            Caption = 'Hit Rate %';
            ToolTip = 'Specifies the share of correctly predicted directions. Around 50% means the method has no predictive power.';
            DecimalPlaces = 0 : 2;
        }
        field(13; MAE; Decimal)
        {
            Caption = 'MAE';
            ToolTip = 'Specifies the mean absolute error of the predicted price.';
            DecimalPlaces = 0 : 8;
        }
        field(14; "Naive MAE"; Decimal)
        {
            Caption = 'Naive MAE';
            ToolTip = 'Specifies the mean absolute error of the naive forecast "the price will not change".';
            DecimalPlaces = 0 : 8;
        }
        field(15; "Skill %"; Decimal)
        {
            Caption = 'Skill %';
            ToolTip = 'Specifies how much smaller the error is compared to the naive forecast. Values at or below 0 mean the method is no better than assuming no change.';
            DecimalPlaces = 0 : 2;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Pair; "Pair Code", "Run At") { }
    }
}
