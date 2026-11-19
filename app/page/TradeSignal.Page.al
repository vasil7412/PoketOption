page 50107 "SMA Trade Signal"
{
    Caption = 'Trade Signal';
    PageType = Worksheet;
    SourceTable = "SMA Trade Signal";
    SourceTableTemporary = true;
    UsageCategory = None;
    ApplicationArea = All;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    Editable = false;
    DataCaptionExpression = CurrencyPair.Code + ' ' + CurrencyPair.Description;

    layout
    {
        area(Content)
        {
            group(Recommendation)
            {
                Caption = 'Recommendation';

                field(RecommendationText; RecommendationText)
                {
                    Caption = 'Trade';
                    ToolTip = 'Specifies the recommended direction and expiration of the trade, or NO TRADE if no expiration has a reliable edge.';
                    StyleExpr = RecommendationStyle;
                }
                field(ReasonText; ReasonText)
                {
                    Caption = 'Reason';
                    ToolTip = 'Specifies why the trade is or is not recommended.';
                    MultiLine = true;
                }
                field(PriceText; PriceText)
                {
                    Caption = 'Based On';
                    ToolTip = 'Specifies the price and the candle the signal is based on.';
                }
                field(DisclaimerText; DisclaimerTxt)
                {
                    Caption = 'Note';
                    ToolTip = 'Specifies how to interpret the signal.';
                    MultiLine = true;
                    Style = Subordinate;
                }
            }
            repeater(Signals)
            {
                Caption = 'Candidates';

                field("Expiration (Min)"; Rec."Expiration (Min)")
                {
                    StyleExpr = LineStyle;
                }
                field(Method; Rec.Method) { }
                field(Direction; Rec.Direction)
                {
                    StyleExpr = DirectionStyle;
                }
                field("No Conflict"; Rec."No Conflict") { }
                field("Agree Count"; Rec."Agree Count") { }
                field("Disagree Count"; Rec."Disagree Count") { }
                field("Hit Rate %"; Rec."Hit Rate %") { }
                field("Hour Hit Rate %"; Rec."Hour Hit Rate %") { }
                field("Conservative Hit Rate %"; Rec."Conservative Hit Rate %")
                {
                    StyleExpr = EdgeStyle;
                }
                field("Breakeven %"; Rec."Breakeven %") { }
                field("Edge %"; Rec."Edge %")
                {
                    StyleExpr = EdgeStyle;
                }
                field(Samples; Rec.Samples) { }
                field(Hits; Rec.Hits) { }
                field("Hour Samples"; Rec."Hour Samples") { }
                field("Live Priority"; Rec."Live Priority") { }
                field("Live Hit Rate %"; Rec."Live Hit Rate %") { }
                field("Live Samples"; Rec."Live Samples") { }
                field("Expected Change %"; Rec."Expected Change %") { }
                field(Strength; Rec.Strength) { }
                field("Predicted Price"; Rec."Predicted Price") { }
                field(Recommended; Rec.Recommended) { }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RefreshSignal)
            {
                Caption = 'Refresh';
                ToolTip = 'Rebuilds the signal on the latest stored candles.';
                Image = Refresh;

                trigger OnAction()
                begin
                    BuildSignal();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            actionref(RefreshSignal_Promoted; RefreshSignal) { }
        }
    }

    trigger OnOpenPage()
    begin
        BuildSignal();
    end;

    trigger OnAfterGetRecord()
    begin
        LineStyle := 'Standard';
        if Rec.Recommended then
            LineStyle := 'StrongAccent';
        case Rec.Direction of
            "SMA Trade Direction"::Up:
                DirectionStyle := 'Favorable';
            "SMA Trade Direction"::Down:
                DirectionStyle := 'Unfavorable';
            else
                DirectionStyle := 'Subordinate';
        end;
        EdgeStyle := 'Unfavorable';
        if Rec."Edge %" > 0 then
            EdgeStyle := 'Favorable';
    end;

    var
        CurrencyPair: Record "SMA Currency Pair";
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        TradeSignalMgt: Codeunit "SMA Trade Signal Mgt";
        RecommendationText: Text;
        RecommendationStyle: Text;
        ReasonText: Text;
        PriceText: Text;
        LineStyle: Text;
        DirectionStyle: Text;
        EdgeStyle: Text;
        TradeTxt: Label '%1 for %2 min', Comment = '%1 = direction, %2 = expiration in minutes';
        NoTradeTxt: Label 'NO TRADE';
        TradeReasonTxt: Label 'Метод %1 прогнозує рух %2 на %3 хв. На історії він вгадав напрямок у %4% з %5 угод. З поправкою на %6 порівняних варіантів його точність з упевненістю 95% щонайменше %7%, а беззбитковість при виплаті %8% становить %9%.', Comment = '%1 = method, %2 = direction, %3 = minutes, %4 = hit rate, %5 = samples, %6 = candidates, %7 = conservative hit rate, %8 = payout, %9 = breakeven';
        AgreementTxt: Label ' Згодних методів: %1, проти: %2. Серед тих, що проти, немає жодного з підтвердженою перевагою.', Comment = '%1 = agreeing methods, %2 = disagreeing methods';
        NoEdgeReasonTxt: Label 'Жодна експірація не має надійної переваги. Найкращий кандидат: %1 на %2 хв, метод %3. З поправкою на %4 порівняних варіантів він вгадує щонайменше %5% напрямків на %6 угодах, а при виплаті %7% потрібно %8%.', Comment = '%1 = direction, %2 = minutes, %3 = method, %4 = candidates, %5 = conservative hit rate, %6 = samples, %7 = payout, %8 = breakeven';
        NoConsensusTxt: Label ' Крім того, інший метод з підтвердженою перевагою прогнозує протилежний напрямок.';
        FewSamplesTxt: Label ' Вдалося перевірити лише %1 історичних угод, а потрібно щонайменше %2. Завантажте більше історії або зменште Signal Min. Samples у налаштуваннях.', Comment = '%1 = samples, %2 = required';
        HourFilterTxt: Label ' Враховано лише угоди, відкриті з %1:00 до %1:59.', Comment = '%1 = hour';
        HourHistoryTxt: Label ' Для фільтра за годиною потрібна історія за кілька днів: збільште Signal Backtest Candles та Initial History Days.';
        NoDirectionTxt: Label 'Усі методи прогнозують, що ціна не зміниться.';
        PriceTxt: Label '%1 at %2', Comment = '%1 = price, %2 = candle time';
        DirectionUpTxt: Label 'вгору (CALL)';
        DirectionDownTxt: Label 'вниз (PUT)';
        DisclaimerTxt: Label 'Сигнал є статистичною оцінкою на основі минулих цін, а не гарантією. Короткострокові рухи ціни майже випадкові, тому точність близько 50% це нормально. Відкривайте угоду одразу: сигнал побудовано на останній збереженій свічці.';

    procedure SetPair(NewCurrencyPair: Record "SMA Currency Pair")
    begin
        CurrencyPair := NewCurrencyPair;
    end;

    local procedure BuildSignal()
    var
        Found: Boolean;
    begin
        RateAnalyzerSetup.GetRecordOnce();
        Found := TradeSignalMgt.BuildSignals(CurrencyPair, Rec);
        if Found then begin
            Rec.SetRange(Recommended, true);
            Rec.FindFirst();
            Rec.Reset();
            RecommendationText := StrSubstNo(TradeTxt, UpperCase(Format(Rec.Direction)), Rec."Expiration (Min)");
            RecommendationStyle := 'Favorable';
            if Rec.Direction = "SMA Trade Direction"::Down then
                RecommendationStyle := 'Unfavorable';
            ReasonText := StrSubstNo(TradeReasonTxt, Rec.Method, DirectionText(Rec.Direction), Rec."Expiration (Min)",
                UsedHitRate(), TradeSignalMgt.GetUsedSamples(Rec), TradeSignalMgt.GetCandidateCount(),
                Rec."Conservative Hit Rate %", RateAnalyzerSetup.GetPayoutPct(), Rec."Breakeven %");
            ReasonText += StrSubstNo(AgreementTxt, Rec."Agree Count", Rec."Disagree Count");
            if TradeSignalMgt.IsTimeFilterUsed() then
                ReasonText += StrSubstNo(HourFilterTxt, TradeSignalMgt.GetSignalHour());
        end else begin
            RecommendationText := NoTradeTxt;
            RecommendationStyle := 'Attention';
            if TradeSignalMgt.FindBestCandidate(Rec) then begin
                ReasonText := StrSubstNo(NoEdgeReasonTxt, DirectionText(Rec.Direction), Rec."Expiration (Min)", Rec.Method,
                    TradeSignalMgt.GetCandidateCount(), Rec."Conservative Hit Rate %", TradeSignalMgt.GetUsedSamples(Rec),
                    RateAnalyzerSetup.GetPayoutPct(), Rec."Breakeven %");
                if not Rec."No Conflict" then
                    ReasonText += NoConsensusTxt;
                if TradeSignalMgt.IsTimeFilterUsed() then
                    ReasonText += StrSubstNo(HourFilterTxt, TradeSignalMgt.GetSignalHour());
                if TradeSignalMgt.GetUsedSamples(Rec) < RateAnalyzerSetup.GetSignalMinSamples() then begin
                    ReasonText += StrSubstNo(FewSamplesTxt, TradeSignalMgt.GetUsedSamples(Rec), RateAnalyzerSetup.GetSignalMinSamples());
                    if TradeSignalMgt.IsTimeFilterUsed() then
                        ReasonText += HourHistoryTxt;
                end;
            end else
                ReasonText := NoDirectionTxt;
        end;
        PriceText := '';
        if Rec.FindFirst() then
            PriceText := StrSubstNo(PriceTxt, Rec."Base Price", Rec."Base Time");

        // recommended first, then by edge
        Rec.Reset();
        Rec.SetCurrentKey(Recommended, "Edge %");
        Rec.Ascending(false);
        if Rec.FindFirst() then;
    end;

    local procedure UsedHitRate(): Decimal
    begin
        if TradeSignalMgt.IsTimeFilterUsed() then
            exit(Rec."Hour Hit Rate %");
        exit(Rec."Hit Rate %");
    end;

    local procedure DirectionText(TradeDirection: Enum "SMA Trade Direction"): Text
    begin
        case TradeDirection of
            "SMA Trade Direction"::Up:
                exit(DirectionUpTxt);
            "SMA Trade Direction"::Down:
                exit(DirectionDownTxt);
        end;
        exit(Format(TradeDirection));
    end;
}
