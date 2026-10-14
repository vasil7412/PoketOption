page 50103 "SMA Rate Candles"
{
    Caption = 'Rate Candles';
    PageType = List;
    SourceTable = "SMA Rate Candle";
    SourceTableView = sorting("Pair Code", Timeframe, "Open Time") order(descending);
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Candles)
            {
                field("Pair Code"; Rec."Pair Code") { }
                field(Timeframe; Rec.Timeframe) { }
                field("Open Time"; Rec."Open Time") { }
                field(Open; Rec.Open) { }
                field(High; Rec.High) { }
                field(Low; Rec.Low) { }
                field(Close; Rec.Close) { }
                field(Volume; Rec.Volume) { }
                field(Complete; Rec.Complete) { }
            }
        }
    }
}
