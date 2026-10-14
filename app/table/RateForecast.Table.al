table 50103 "SMA Rate Forecast"
{
    Caption = 'Rate Forecast';
    DataClassification = CustomerContent;
    DrillDownPageId = "SMA Rate Forecasts";
    LookupPageId = "SMA Rate Forecasts";

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
            ToolTip = 'Specifies the candle timeframe the forecast is built on.';
        }
        field(3; "Base Time"; DateTime)
        {
            Caption = 'Base Time';
            ToolTip = 'Specifies the open time of the last candle the forecast is based on.';
        }
        field(4; Step; Integer)
        {
            Caption = 'Step';
            ToolTip = 'Specifies how many candles ahead of the base candle this forecast point is.';
        }
        field(5; "Target Time"; DateTime)
        {
            Caption = 'Target Time';
            ToolTip = 'Specifies the open time of the candle this forecast point predicts.';
        }
        field(6; Method; Enum "SMA Forecast Method")
        {
            Caption = 'Method';
            ToolTip = 'Specifies the forecast method.';
        }
        field(7; "Base Close"; Decimal)
        {
            Caption = 'Base Close';
            ToolTip = 'Specifies the close price of the base candle.';
            DecimalPlaces = 0 : 8;
        }
        field(8; "Predicted Close"; Decimal)
        {
            Caption = 'Predicted Close';
            ToolTip = 'Specifies the predicted close price of the target candle.';
            DecimalPlaces = 0 : 8;
        }
        field(9; "Lower Bound"; Decimal)
        {
            Caption = 'Lower Bound';
            ToolTip = 'Specifies the lower bound of the confidence band.';
            DecimalPlaces = 0 : 8;
        }
        field(10; "Upper Bound"; Decimal)
        {
            Caption = 'Upper Bound';
            ToolTip = 'Specifies the upper bound of the confidence band.';
            DecimalPlaces = 0 : 8;
        }
        field(11; "Horizon Step"; Boolean)
        {
            Caption = 'Horizon Step';
            ToolTip = 'Specifies whether this is the last step of the forecast, which is used for accuracy statistics.';
        }
        field(12; "Created At"; DateTime)
        {
            Caption = 'Created At';
            ToolTip = 'Specifies when the forecast was calculated.';
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
        field(22; "Direction Hit"; Boolean)
        {
            Caption = 'Direction Hit';
            ToolTip = 'Specifies whether the forecast predicted the direction of the price move from the base close correctly.';
        }
        field(23; "Abs. Error"; Decimal)
        {
            Caption = 'Abs. Error';
            ToolTip = 'Specifies the absolute difference between the predicted and the actual close price.';
            DecimalPlaces = 0 : 8;
        }
    }

    keys
    {
        key(PK; "Pair Code", Timeframe, "Base Time", Step)
        {
            Clustered = true;
        }
        key(Evaluation; "Pair Code", Timeframe, Evaluated, "Target Time") { }
        key(Horizon; "Pair Code", Timeframe, "Horizon Step", Evaluated, "Direction Hit", "Target Time") { }
    }
}
