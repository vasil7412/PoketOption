page 50100 "SMA Rate Analyzer Setup"
{
    Caption = 'Rate Analyzer Setup';
    PageType = Card;
    SourceTable = "SMA Rate Analyzer Setup";
    UsageCategory = Administration;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Refresh)
            {
                Caption = 'Refresh';

                field("Refresh Interval (Sec)"; Rec."Refresh Interval (Sec)") { }
                field("Live Fetch on Refresh"; Rec."Live Fetch on Refresh") { }
                field("Chart Candles"; Rec."Chart Candles") { }
            }
            group(Forecast)
            {
                Caption = 'Forecast';

                field("Default Forecast Method"; Rec."Default Forecast Method") { }
                field("Default Horizon (Min)"; Rec."Default Horizon (Min)") { }
                field("Lookback Candles"; Rec."Lookback Candles") { }
                field("Band Width (Std. Dev.)"; Rec."Band Width (Std. Dev.)") { }
                field("Holt Alpha"; Rec."Holt Alpha") { }
                field("Holt Beta"; Rec."Holt Beta") { }
                field("Holt Damping"; Rec."Holt Damping") { }
                field("Backtest Candles"; Rec."Backtest Candles") { }
            }
            group(Signal)
            {
                Caption = 'Trade Signal';

                field("Payout %"; Rec."Payout %") { }
                field("Signal Expirations (Min)"; Rec."Signal Expirations (Min)") { }
                field("Signal Backtest Candles"; Rec."Signal Backtest Candles") { }
                field("Signal Min. Samples"; Rec."Signal Min. Samples") { }
                field("Time-of-Day Filter"; Rec."Time-of-Day Filter") { }
            }
            group(Methods)
            {
                Caption = 'Forecast Methods';

                field("AR Order"; Rec."AR Order") { }
                field("Mean Reversion Period"; Rec."Mean Reversion Period") { }
                field("Mean Reversion Z"; Rec."Mean Reversion Z") { }
                field("RSI Period"; Rec."RSI Period") { }
                field("RSI Oversold"; Rec."RSI Oversold") { }
                field("RSI Overbought"; Rec."RSI Overbought") { }
                field("Stochastic Period"; Rec."Stochastic Period") { }
                field("Stochastic Smoothing"; Rec."Stochastic Smoothing") { }
                field("Stochastic Oversold"; Rec."Stochastic Oversold") { }
                field("Stochastic Overbought"; Rec."Stochastic Overbought") { }
                field("Ensemble Weight Candles"; Rec."Ensemble Weight Candles") { }
                field("Logistic Training Candles"; Rec."Logistic Training Candles") { }
                field("Logistic Refit Interval"; Rec."Logistic Refit Interval") { }
                field("Logistic Min. Probability %"; Rec."Logistic Min. Probability %") { }
            }
            group(Learning)
            {
                Caption = 'Live Learning';

                field("Disable Live Tracking"; Rec."Disable Live Tracking") { }
                field("Tracking Interval (Min)"; Rec."Tracking Interval (Min)") { }
                field("Learning Decay"; Rec."Learning Decay") { }
                field("Min. Live Samples"; Rec."Min. Live Samples") { }
            }
            group(History)
            {
                Caption = 'History';

                field("Initial History Days"; Rec."Initial History Days") { }
                field("Keep History Days"; Rec."Keep History Days") { }
                field("Keep Forecasts Days"; Rec."Keep Forecasts Days") { }
            }
            group(Providers)
            {
                Caption = 'Data Providers';

                field(TwelveDataApiKey; TwelveDataApiKey)
                {
                    Caption = 'Twelve Data API Key';
                    ToolTip = 'Specifies the API key from twelvedata.com. The free plan allows 800 requests per day and 8 per minute.';
                    ExtendedDatatype = Masked;

                    trigger OnValidate()
                    begin
                        Rec.SetTwelveDataApiKey(TwelveDataApiKey);
                    end;
                }
                field("Binance Base URL"; Rec."Binance Base URL") { }
                field("OANDA Environment"; Rec."OANDA Environment") { }
                field(OANDAToken; OANDAToken)
                {
                    Caption = 'OANDA API Token';
                    ToolTip = 'Specifies the personal access token of your OANDA account (a free practice account is enough).';
                    ExtendedDatatype = Masked;

                    trigger OnValidate()
                    begin
                        Rec.SetOANDAToken(OANDAToken);
                    end;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CreateDefaultPairs)
            {
                Caption = 'Create Default Pairs';
                ToolTip = 'Creates sample currency pairs: BTCUSDT and ETHUSDT from Binance (no key needed), EURUSD, GBPUSD and USDJPY from Biquote (no key needed).';
                Image = Setup;

                trigger OnAction()
                var
                    RateAnalyzerMgt: Codeunit "SMA Rate Analyzer Mgt";
                begin
                    RateAnalyzerMgt.CreateDefaultPairs();
                end;
            }
            action(CreateJobQueueEntry)
            {
                Caption = 'Create Job Queue Entry';
                ToolTip = 'Creates a job queue entry that downloads rates and builds forecasts for all active pairs every minute.';
                Image = Job;

                trigger OnAction()
                var
                    RateAnalyzerMgt: Codeunit "SMA Rate Analyzer Mgt";
                begin
                    RateAnalyzerMgt.CreateJobQueueEntry();
                end;
            }
        }
        area(Navigation)
        {
            action(CurrencyPairs)
            {
                Caption = 'Currency Pairs';
                ToolTip = 'Opens the list of currency pairs.';
                Image = Currencies;
                RunObject = page "SMA Currency Pairs";
            }
        }
        area(Promoted)
        {
            actionref(CreateDefaultPairs_Promoted; CreateDefaultPairs) { }
            actionref(CreateJobQueueEntry_Promoted; CreateJobQueueEntry) { }
            actionref(CurrencyPairs_Promoted; CurrencyPairs) { }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.InsertIfNotExists();
        if Rec.HasTwelveDataApiKey() then
            TwelveDataApiKey := MaskTxt;
        if Rec.HasOANDAToken() then
            OANDAToken := MaskTxt;
    end;

    var
        [NonDebuggable]
        TwelveDataApiKey: Text;
        [NonDebuggable]
        OANDAToken: Text;
        MaskTxt: Label '***************', Locked = true;
}
