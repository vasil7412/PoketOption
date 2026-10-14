codeunit 50112 "SMA Rate Analyzer Install"
{
    Subtype = Install;
    Access = Internal;

    trigger OnInstallAppPerCompany()
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
    begin
        RateAnalyzerSetup.InsertIfNotExists();
    end;
}
