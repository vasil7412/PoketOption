codeunit 50115 "SMA Rate Analyzer Mgt"
{
    Permissions =
        tabledata "SMA Currency Pair" = ri,
        tabledata "Job Queue Entry" = rim;

    var
        JobDescriptionLbl: Label 'Rate Analyzer: download rates and build forecasts';
        JobCreatedMsg: Label 'The job queue entry has been created and started. It runs every minute.';
        JobExistsMsg: Label 'The job queue entry already exists. Its status is %1.', Comment = '%1 = status';
        PairsCreatedMsg: Label '%1 currency pairs have been created. Binance pairs work without an API key and are active. Forex pairs need a Twelve Data API key and are inactive.', Comment = '%1 = number of pairs';

    procedure CreateDefaultPairs()
    var
        CreatedCount: Integer;
    begin
        CreatedCount += CreatePair('BTCUSDT', 'Bitcoin / Tether', 'BTC', 'USDT', "SMA Rate Data Provider"::Binance, 2, true);
        CreatedCount += CreatePair('ETHUSDT', 'Ethereum / Tether', 'ETH', 'USDT', "SMA Rate Data Provider"::Binance, 2, true);
        CreatedCount += CreatePair('EURUSD', 'Euro / US Dollar', 'EUR', 'USD', "SMA Rate Data Provider"::"Twelve Data", 5, false);
        CreatedCount += CreatePair('GBPUSD', 'British Pound / US Dollar', 'GBP', 'USD', "SMA Rate Data Provider"::"Twelve Data", 5, false);
        CreatedCount += CreatePair('USDJPY', 'US Dollar / Japanese Yen', 'USD', 'JPY', "SMA Rate Data Provider"::"Twelve Data", 3, false);
        Message(PairsCreatedMsg, CreatedCount);
    end;

    procedure CreateJobQueueEntry()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"SMA Rate Sync Job");
        if JobQueueEntry.FindFirst() then begin
            Message(JobExistsMsg, JobQueueEntry.Status);
            exit;
        end;

        JobQueueEntry.Init();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"SMA Rate Sync Job";
        JobQueueEntry.Description := CopyStr(JobDescriptionLbl, 1, MaxStrLen(JobQueueEntry.Description));
        JobQueueEntry."Recurring Job" := true;
        JobQueueEntry."Run on Mondays" := true;
        JobQueueEntry."Run on Tuesdays" := true;
        JobQueueEntry."Run on Wednesdays" := true;
        JobQueueEntry."Run on Thursdays" := true;
        JobQueueEntry."Run on Fridays" := true;
        JobQueueEntry."Run on Saturdays" := true;
        JobQueueEntry."Run on Sundays" := true;
        JobQueueEntry."No. of Minutes between Runs" := 1;
        JobQueueEntry."Maximum No. of Attempts to Run" := 3;
        JobQueueEntry."Rerun Delay (sec.)" := 30;
        JobQueueEntry."Earliest Start Date/Time" := CurrentDateTime();
        Codeunit.Run(Codeunit::"Job Queue - Enqueue", JobQueueEntry);
        Message(JobCreatedMsg);
    end;

    local procedure CreatePair(PairCode: Code[20]; PairDescription: Text[100]; BaseCurrency: Code[10]; QuoteCurrency: Code[10]; Provider: Enum "SMA Rate Data Provider"; PriceDecimals: Integer; IsActive: Boolean): Integer
    var
        CurrencyPair: Record "SMA Currency Pair";
    begin
        if CurrencyPair.Get(PairCode) then
            exit(0);
        CurrencyPair.Init();
        CurrencyPair.Code := PairCode;
        CurrencyPair.Description := PairDescription;
        CurrencyPair.Validate(Provider, Provider);
        CurrencyPair.Validate("Base Currency", BaseCurrency);
        CurrencyPair.Validate("Quote Currency", QuoteCurrency);
        CurrencyPair."Price Decimals" := PriceDecimals;
        CurrencyPair.Active := IsActive;
        CurrencyPair.Insert(true);
        exit(1);
    end;
}
