/// <summary>
/// Job queue entry point: processes all active pairs and deletes old data.
/// </summary>
codeunit 50109 "SMA Rate Sync Job"
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    begin
        ProcessActivePairs();
    end;

    procedure ProcessActivePairs()
    var
        CurrencyPair: Record "SMA Currency Pair";
        RateSyncMgt: Codeunit "SMA Rate Sync Mgt";
    begin
        CurrencyPair.SetRange(Active, true);
        if CurrencyPair.FindSet() then
            repeat
                Commit();
                ClearLastError();
                if not Codeunit.Run(Codeunit::"SMA Rate Pair Processor", CurrencyPair) then
                    RateSyncMgt.SetSyncError(CurrencyPair, GetLastErrorText());
            until CurrencyPair.Next() = 0;

        Commit();
        RateSyncMgt.PurgeOldData();
    end;
}
