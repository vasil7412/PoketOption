page 50106 "SMA Backtest Results"
{
    Caption = 'Backtest Results';
    PageType = List;
    SourceTable = "SMA Backtest Result";
    SourceTableView = sorting("Entry No.") order(descending);
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Results)
            {
                field("Pair Code"; Rec."Pair Code") { }
                field(Timeframe; Rec.Timeframe) { }
                field(Method; Rec.Method) { }
                field("Horizon (Min)"; Rec."Horizon (Min)") { }
                field("Hit Rate %"; Rec."Hit Rate %")
                {
                    StyleExpr = HitRateStyle;
                }
                field("Skill %"; Rec."Skill %")
                {
                    StyleExpr = SkillStyle;
                }
                field(Samples; Rec.Samples) { }
                field("Direction Hits"; Rec."Direction Hits") { }
                field(MAE; Rec.MAE) { }
                field("Naive MAE"; Rec."Naive MAE") { }
                field("Lookback Candles"; Rec."Lookback Candles") { }
                field("From Time"; Rec."From Time") { }
                field("To Time"; Rec."To Time") { }
                field("Run At"; Rec."Run At") { }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        HitRateStyle := '';
        if Rec."Hit Rate %" >= 55 then
            HitRateStyle := 'Favorable';
        if Rec."Hit Rate %" < 50 then
            HitRateStyle := 'Unfavorable';
        SkillStyle := '';
        if Rec."Skill %" > 0 then
            SkillStyle := 'Favorable';
        if Rec."Skill %" < 0 then
            SkillStyle := 'Unfavorable';
    end;

    var
        HitRateStyle: Text;
        SkillStyle: Text;
}
