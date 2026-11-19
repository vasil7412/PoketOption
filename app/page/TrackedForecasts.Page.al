page 50109 "SMA Tracked Forecasts"
{
    Caption = 'Tracked Forecasts (Live)';
    PageType = List;
    SourceTable = "SMA Tracked Forecast";
    SourceTableView = sorting("Pair Code", Timeframe, "Base Time", Method, "Expiration (Min)") order(descending);
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Forecasts)
            {
                field("Pair Code"; Rec."Pair Code") { }
                field(Timeframe; Rec.Timeframe) { }
                field("Base Time"; Rec."Base Time") { }
                field(Method; Rec.Method) { }
                field("Expiration (Min)"; Rec."Expiration (Min)") { }
                field(Direction; Rec.Direction) { }
                field("Base Close"; Rec."Base Close") { }
                field("Predicted Close"; Rec."Predicted Close") { }
                field("Target Time"; Rec."Target Time") { }
                field(Evaluated; Rec.Evaluated) { }
                field("Actual Close"; Rec."Actual Close") { }
                field("Actual Direction"; Rec."Actual Direction") { }
                field(Counted; Rec.Counted) { }
                field(Hit; Rec.Hit)
                {
                    StyleExpr = HitStyle;
                }
                field("Created At"; Rec."Created At") { }
                field("Evaluated At"; Rec."Evaluated At") { }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        HitStyle := 'Standard';
        if Rec.Counted then
            if Rec.Hit then
                HitStyle := 'Favorable'
            else
                HitStyle := 'Unfavorable';
    end;

    var
        HitStyle: Text;
}
