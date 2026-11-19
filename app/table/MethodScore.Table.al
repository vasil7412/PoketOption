/// <summary>
/// Live track record of a forecast method for a pair and an expiration. Learned from the tracked forecasts:
/// recent results weigh more (exponential decay), the best methods get the highest priority and weight.
/// </summary>
table 50107 "SMA Method Score"
{
    Caption = 'Method Score';
    DataClassification = CustomerContent;
    DrillDownPageId = "SMA Method Scores";
    LookupPageId = "SMA Method Scores";

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
        field(3; Method; Enum "SMA Forecast Method")
        {
            Caption = 'Method';
            ToolTip = 'Specifies the forecast method.';
        }
        field(4; "Expiration (Min)"; Integer)
        {
            Caption = 'Expiration (Min)';
            ToolTip = 'Specifies the expiration the score is measured for.';
        }
        field(10; Samples; Integer)
        {
            Caption = 'Samples';
            ToolTip = 'Specifies how many live forecasts of the method were checked (with a predicted direction and an actual price change).';
        }
        field(11; Hits; Integer)
        {
            Caption = 'Hits';
            ToolTip = 'Specifies how many of the checked live forecasts predicted the direction correctly.';
        }
        field(12; "Hit Rate %"; Decimal)
        {
            Caption = 'Hit Rate %';
            ToolTip = 'Specifies the share of correct directions over all checked live forecasts.';
            DecimalPlaces = 0 : 2;
        }
        field(13; "Decayed Samples"; Decimal)
        {
            Caption = 'Decayed Samples';
            ToolTip = 'Specifies the number of checked forecasts where every older result counts less (multiplied by the learning decay on every new result).';
            DecimalPlaces = 0 : 2;
        }
        field(14; "Decayed Hits"; Decimal)
        {
            Caption = 'Decayed Hits';
            ToolTip = 'Specifies the number of correct forecasts where every older result counts less.';
            DecimalPlaces = 0 : 2;
        }
        field(15; "Recent Hit Rate %"; Decimal)
        {
            Caption = 'Recent Hit Rate %';
            ToolTip = 'Specifies the hit rate that favours the latest results. It decides the priority and the weight of the method.';
            DecimalPlaces = 0 : 2;
        }
        field(16; Weight; Decimal)
        {
            Caption = 'Weight';
            ToolTip = 'Specifies the weight of the method in the adaptive forecast: recent hit rate minus 50%. Methods at or below 50%, or with fewer samples than required, get no weight.';
            DecimalPlaces = 0 : 4;
        }
        field(17; Priority; Integer)
        {
            Caption = 'Priority';
            ToolTip = 'Specifies the rank of the method for the pair and expiration: 1 is the best. Methods with too few samples are ranked last.';
        }
        field(18; "Last Evaluated At"; DateTime)
        {
            Caption = 'Last Evaluated At';
            ToolTip = 'Specifies when the last live forecast of the method was checked.';
        }
    }

    keys
    {
        key(PK; "Pair Code", Timeframe, Method, "Expiration (Min)")
        {
            Clustered = true;
        }
        key(Rank; "Pair Code", Timeframe, "Expiration (Min)", "Recent Hit Rate %") { }
        key(Priority; "Pair Code", Timeframe, "Expiration (Min)", Priority) { }
    }
}
