page 50104 "SMA Rate Forecasts"
{
    Caption = 'Rate Forecasts';
    PageType = List;
    SourceTable = "SMA Rate Forecast";
    SourceTableView = sorting("Pair Code", Timeframe, "Base Time", Step) order(descending);
    ApplicationArea = All;
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
                field(Step; Rec.Step) { }
                field("Target Time"; Rec."Target Time") { }
                field(Method; Rec.Method) { }
                field("Base Close"; Rec."Base Close") { }
                field("Predicted Close"; Rec."Predicted Close") { }
                field("Lower Bound"; Rec."Lower Bound") { }
                field("Upper Bound"; Rec."Upper Bound") { }
                field("Horizon Step"; Rec."Horizon Step") { }
                field(Evaluated; Rec.Evaluated) { }
                field("Actual Close"; Rec."Actual Close") { }
                field("Direction Hit"; Rec."Direction Hit")
                {
                    StyleExpr = HitStyle;
                }
                field("Abs. Error"; Rec."Abs. Error") { }
                field("Created At"; Rec."Created At") { }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(HorizonOnly)
            {
                Caption = 'Show Horizon Only';
                ToolTip = 'Shows only the last step of every forecast, which is used for the accuracy statistics.';
                Image = FilterLines;

                trigger OnAction()
                begin
                    Rec.SetRange("Horizon Step", true);
                    CurrPage.Update(false);
                end;
            }
            action(AllSteps)
            {
                Caption = 'Show All Steps';
                ToolTip = 'Shows every step of every forecast.';
                Image = ClearFilter;

                trigger OnAction()
                begin
                    Rec.SetRange("Horizon Step");
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            actionref(HorizonOnly_Promoted; HorizonOnly) { }
            actionref(AllSteps_Promoted; AllSteps) { }
        }
    }

    trigger OnAfterGetRecord()
    begin
        HitStyle := '';
        if Rec.Evaluated then
            if Rec."Direction Hit" then
                HitStyle := 'Favorable'
            else
                HitStyle := 'Unfavorable';
    end;

    var
        HitStyle: Text;
}
