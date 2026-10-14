table 50101 "SMA Currency Pair"
{
    Caption = 'Currency Pair';
    DataClassification = CustomerContent;
    DrillDownPageId = "SMA Currency Pairs";
    LookupPageId = "SMA Currency Pairs";

    fields
    {
        field(1; "Code"; Code[20])
        {
            Caption = 'Code';
            ToolTip = 'Specifies the code of the currency pair, for example EURUSD.';
            NotBlank = true;
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
            ToolTip = 'Specifies the description of the currency pair.';
        }
        field(3; "Base Currency"; Code[10])
        {
            Caption = 'Base Currency';
            ToolTip = 'Specifies the base currency of the pair, for example EUR in EUR/USD.';

            trigger OnValidate()
            begin
                UpdateProviderSymbol();
            end;
        }
        field(4; "Quote Currency"; Code[10])
        {
            Caption = 'Quote Currency';
            ToolTip = 'Specifies the quote currency of the pair, for example USD in EUR/USD.';

            trigger OnValidate()
            begin
                UpdateProviderSymbol();
            end;
        }
        field(5; Provider; Enum "SMA Rate Data Provider")
        {
            Caption = 'Provider';
            ToolTip = 'Specifies the market data provider the rate history is downloaded from.';

            trigger OnValidate()
            begin
                UpdateProviderSymbol();
            end;
        }
        field(6; "Provider Symbol"; Text[30])
        {
            Caption = 'Provider Symbol';
            ToolTip = 'Specifies the instrument symbol as the provider expects it, for example EUR/USD for Twelve Data, EUR_USD for OANDA, BTCUSDT for Binance.';
        }
        field(7; Timeframe; Enum "SMA Rate Timeframe")
        {
            Caption = 'Timeframe';
            ToolTip = 'Specifies the candle timeframe. Twelve Data and Binance support 1 min and 5 min, OANDA also supports 15 sec and 30 sec.';
            InitValue = "1 Min";

            trigger OnValidate()
            begin
                if Timeframe <> xRec.Timeframe then
                    "Last Candle Time" := 0DT;
            end;
        }
        field(8; Active; Boolean)
        {
            Caption = 'Active';
            ToolTip = 'Specifies whether the job queue downloads rates and builds forecasts for this pair.';
        }
        field(9; "Price Decimals"; Integer)
        {
            Caption = 'Price Decimals';
            ToolTip = 'Specifies how many decimals are shown for prices of this pair.';
            InitValue = 5;
            MinValue = 0;
            MaxValue = 8;
        }
        field(10; "Forecast Method"; Enum "SMA Forecast Method")
        {
            Caption = 'Forecast Method';
            ToolTip = 'Specifies the forecast method used for stored forecasts and accuracy statistics of this pair.';
        }
        field(11; "Forecast Horizon (Min)"; Integer)
        {
            Caption = 'Forecast Horizon (Min)';
            ToolTip = 'Specifies how many minutes ahead the forecast is built.';
            MinValue = 1;
            MaxValue = 60;
        }
        field(20; "Last Candle Time"; DateTime)
        {
            Caption = 'Last Candle Time';
            ToolTip = 'Specifies the open time of the latest downloaded candle.';
            Editable = false;
        }
        field(21; "Last Sync At"; DateTime)
        {
            Caption = 'Last Sync At';
            ToolTip = 'Specifies when rates were last downloaded for this pair.';
            Editable = false;
        }
        field(22; "Last Sync Error"; Text[250])
        {
            Caption = 'Last Sync Error';
            ToolTip = 'Specifies the error of the last unsuccessful synchronization.';
            Editable = false;
        }
        field(30; "No. of Candles"; Integer)
        {
            Caption = 'No. of Candles';
            ToolTip = 'Specifies how many candles of the current timeframe are stored.';
            FieldClass = FlowField;
            CalcFormula = count("SMA Rate Candle" where("Pair Code" = field(Code), Timeframe = field(Timeframe)));
            Editable = false;
        }
        field(31; "Evaluated Forecasts"; Integer)
        {
            Caption = 'Evaluated Forecasts';
            ToolTip = 'Specifies how many stored horizon forecasts have already been compared with the actual price.';
            FieldClass = FlowField;
            CalcFormula = count("SMA Rate Forecast" where("Pair Code" = field(Code), Timeframe = field(Timeframe), "Horizon Step" = const(true), Evaluated = const(true)));
            Editable = false;
        }
        field(32; "Direction Hits"; Integer)
        {
            Caption = 'Direction Hits';
            ToolTip = 'Specifies how many evaluated horizon forecasts predicted the price direction correctly.';
            FieldClass = FlowField;
            CalcFormula = count("SMA Rate Forecast" where("Pair Code" = field(Code), Timeframe = field(Timeframe), "Horizon Step" = const(true), Evaluated = const(true), "Direction Hit" = const(true)));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Code")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Code", Description, Provider, Timeframe) { }
    }

    trigger OnInsert()
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
    begin
        if "Forecast Horizon (Min)" = 0 then begin
            RateAnalyzerSetup.GetRecordOnce();
            "Forecast Horizon (Min)" := RateAnalyzerSetup."Default Horizon (Min)";
            "Forecast Method" := RateAnalyzerSetup."Default Forecast Method";
        end;
    end;

    trigger OnDelete()
    var
        RateCandle: Record "SMA Rate Candle";
        RateForecast: Record "SMA Rate Forecast";
        BacktestResult: Record "SMA Backtest Result";
    begin
        RateCandle.SetRange("Pair Code", Code);
        RateCandle.DeleteAll();
        RateForecast.SetRange("Pair Code", Code);
        RateForecast.DeleteAll();
        BacktestResult.SetRange("Pair Code", Code);
        BacktestResult.DeleteAll();
    end;

    procedure GetHitRateText(): Text
    var
        HitRateTxt: Label '%1% (%2 of %3)', Comment = '%1 = hit rate, %2 = hits, %3 = evaluated forecasts';
        NoDataTxt: Label 'no evaluated forecasts yet';
    begin
        CalcFields("Evaluated Forecasts", "Direction Hits");
        if "Evaluated Forecasts" = 0 then
            exit(NoDataTxt);
        exit(StrSubstNo(HitRateTxt, Round("Direction Hits" / "Evaluated Forecasts" * 100, 0.1), "Direction Hits", "Evaluated Forecasts"));
    end;

    local procedure UpdateProviderSymbol()
    var
        RateDataProvider: Interface "SMA IRate Data Provider";
    begin
        if ("Base Currency" = '') or ("Quote Currency" = '') then
            exit;
        RateDataProvider := Provider;
        "Provider Symbol" := RateDataProvider.GetDefaultSymbol("Base Currency", "Quote Currency");
    end;
}
