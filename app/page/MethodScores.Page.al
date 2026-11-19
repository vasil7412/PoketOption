page 50108 "SMA Method Scores"
{
    Caption = 'Method Ranking (Live)';
    PageType = List;
    SourceTable = "SMA Method Score";
    SourceTableView = sorting("Pair Code", Timeframe, "Expiration (Min)", Priority);
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Scores)
            {
                field("Pair Code"; Rec."Pair Code") { }
                field(Timeframe; Rec.Timeframe) { }
                field("Expiration (Min)"; Rec."Expiration (Min)") { }
                field(Priority; Rec.Priority)
                {
                    StyleExpr = RowStyle;
                }
                field(Method; Rec.Method)
                {
                    StyleExpr = RowStyle;
                }
                field("Recent Hit Rate %"; Rec."Recent Hit Rate %")
                {
                    StyleExpr = RowStyle;
                }
                field(Weight; Rec.Weight) { }
                field("Hit Rate %"; Rec."Hit Rate %") { }
                field(Samples; Rec.Samples) { }
                field(Hits; Rec.Hits) { }
                field("Decayed Samples"; Rec."Decayed Samples") { }
                field("Last Evaluated At"; Rec."Last Evaluated At") { }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ResetLearning)
            {
                Caption = 'Reset Learning';
                ToolTip = 'Deletes the learned scores of the pair, for example after you changed the method parameters. The methods start learning from scratch.';
                Image = Restore;

                trigger OnAction()
                var
                    LiveTrackingMgt: Codeunit "SMA Live Tracking Mgt";
                begin
                    if not Confirm(ResetQst, false, Rec."Pair Code", Rec.Timeframe) then
                        exit;
                    LiveTrackingMgt.ResetLearning(Rec."Pair Code", Rec.Timeframe);
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(TrackedForecasts)
            {
                Caption = 'Tracked Forecasts';
                ToolTip = 'Shows the live forecasts the ranking was learned from.';
                Image = Forecast;
                RunObject = page "SMA Tracked Forecasts";
                RunPageLink = "Pair Code" = field("Pair Code"), Timeframe = field(Timeframe), Method = field(Method), "Expiration (Min)" = field("Expiration (Min)");
            }
        }
        area(Promoted)
        {
            actionref(TrackedForecasts_Promoted; TrackedForecasts) { }
            actionref(ResetLearning_Promoted; ResetLearning) { }
        }
    }

    trigger OnAfterGetRecord()
    begin
        RowStyle := 'Standard';
        if Rec.Weight > 0 then
            RowStyle := 'Favorable';
        if (Rec.Weight = 0) and (Rec."Recent Hit Rate %" < 50) then
            RowStyle := 'Unfavorable';
        if Rec.Priority = 1 then
            RowStyle := 'StrongAccent';
    end;

    var
        RowStyle: Text;
        ResetQst: Label 'Delete the learned method scores of %1 %2?', Comment = '%1 = pair, %2 = timeframe';
}
