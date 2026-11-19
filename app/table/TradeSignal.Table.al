/// <summary>
/// One candidate trade: the current forecast of a method for an expiration, together with
/// how often the same method guessed the direction for that expiration on the recent history.
/// </summary>
table 50105 "SMA Trade Signal"
{
    Caption = 'Trade Signal';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            ToolTip = 'Specifies the number of the entry.';
        }
        field(2; "Pair Code"; Code[20])
        {
            Caption = 'Pair Code';
            ToolTip = 'Specifies the currency pair.';
        }
        field(3; Method; Enum "SMA Forecast Method")
        {
            Caption = 'Method';
            ToolTip = 'Specifies the forecast method.';
        }
        field(4; "Expiration (Min)"; Integer)
        {
            Caption = 'Expiration (Min)';
            ToolTip = 'Specifies for how many minutes the trade would be opened.';
        }
        field(5; Steps; Integer)
        {
            Caption = 'Steps';
            ToolTip = 'Specifies how many candles the expiration covers.';
        }
        field(6; Direction; Enum "SMA Trade Direction")
        {
            Caption = 'Direction';
            ToolTip = 'Specifies the direction the method currently predicts for the expiration.';
        }
        field(7; "Base Time"; DateTime)
        {
            Caption = 'Base Time';
            ToolTip = 'Specifies the open time of the latest candle the forecast is based on.';
        }
        field(8; "Base Price"; Decimal)
        {
            Caption = 'Base Price';
            ToolTip = 'Specifies the latest price the forecast is based on.';
            DecimalPlaces = 0 : 8;
        }
        field(9; "Predicted Price"; Decimal)
        {
            Caption = 'Predicted Price';
            ToolTip = 'Specifies the predicted price at the end of the expiration.';
            DecimalPlaces = 0 : 8;
        }
        field(10; "Expected Change %"; Decimal)
        {
            Caption = 'Expected Change %';
            ToolTip = 'Specifies the predicted price change until the end of the expiration.';
            DecimalPlaces = 0 : 4;
        }
        field(11; Strength; Decimal)
        {
            Caption = 'Strength';
            ToolTip = 'Specifies the predicted change divided by the usual price noise for the expiration. Values below 0.5 mean the predicted move is small compared to the noise.';
            DecimalPlaces = 0 : 2;
        }
        field(12; Samples; Integer)
        {
            Caption = 'Samples';
            ToolTip = 'Specifies how many historical forecasts of this method and expiration were checked. Forecasts and outcomes without a price change are not counted.';
        }
        field(13; Hits; Integer)
        {
            Caption = 'Hits';
            ToolTip = 'Specifies how many of the checked historical forecasts predicted the direction correctly.';
        }
        field(14; "Hit Rate %"; Decimal)
        {
            Caption = 'Hit Rate %';
            ToolTip = 'Specifies the share of historical forecasts that predicted the direction correctly.';
            DecimalPlaces = 0 : 2;
        }
        field(15; "Conservative Hit Rate %"; Decimal)
        {
            Caption = 'Conservative Hit Rate %';
            ToolTip = 'Specifies the hit rate the method reaches at least with 95% confidence (lower bound of the Wilson interval), corrected for the number of compared candidates: the more candidates, the more one of them looks good by pure luck. It is lower than the hit rate when there are few samples.';
            DecimalPlaces = 0 : 2;
        }
        field(16; "Breakeven %"; Decimal)
        {
            Caption = 'Breakeven %';
            ToolTip = 'Specifies the hit rate needed not to lose money at the payout from the setup.';
            DecimalPlaces = 0 : 2;
        }
        field(17; "Edge %"; Decimal)
        {
            Caption = 'Edge %';
            ToolTip = 'Specifies how much the conservative hit rate exceeds the breakeven. Only positive values are worth a trade.';
            DecimalPlaces = 0 : 2;
        }
        field(18; "No Conflict"; Boolean)
        {
            Caption = 'No Conflict';
            ToolTip = 'Specifies that no other method with a proven edge (positive Edge % and enough samples) predicts the opposite direction for this expiration.';
        }
        field(19; Recommended; Boolean)
        {
            Caption = 'Recommended';
            ToolTip = 'Specifies whether this is the recommended trade.';
        }
        field(20; "Agree Count"; Integer)
        {
            Caption = 'Agree';
            ToolTip = 'Specifies how many other methods predict the same direction for this expiration.';
        }
        field(21; "Disagree Count"; Integer)
        {
            Caption = 'Disagree';
            ToolTip = 'Specifies how many other methods predict the opposite direction for this expiration.';
        }
        field(22; "Hour Samples"; Integer)
        {
            Caption = 'Hour Samples';
            ToolTip = 'Specifies how many of the checked historical forecasts were made at the same hour of the day as now.';
        }
        field(23; "Hour Hits"; Integer)
        {
            Caption = 'Hour Hits';
            ToolTip = 'Specifies how many of the historical forecasts made at the same hour of the day predicted the direction correctly.';
        }
        field(24; "Hour Hit Rate %"; Decimal)
        {
            Caption = 'Hour Hit Rate %';
            ToolTip = 'Specifies the hit rate of the historical forecasts made at the same hour of the day as now. With the Time-of-Day Filter on, the conservative hit rate and the edge are based on it.';
            DecimalPlaces = 0 : 2;
        }
        field(25; "Live Samples"; Integer)
        {
            Caption = 'Live Samples';
            ToolTip = 'Specifies how many live tracked forecasts of the method were checked for this expiration.';
        }
        field(26; "Live Hit Rate %"; Decimal)
        {
            Caption = 'Live Hit Rate %';
            ToolTip = 'Specifies the recent hit rate of the live tracked forecasts of the method (latest results weigh more).';
            DecimalPlaces = 0 : 2;
        }
        field(27; "Live Priority"; Integer)
        {
            Caption = 'Live Priority';
            ToolTip = 'Specifies the rank of the method in the live ranking for this expiration: 1 is the best, 0 means not ranked yet.';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Rank; Recommended, "Edge %") { }
        key(Expiration; "Expiration (Min)", Method) { }
    }
}
