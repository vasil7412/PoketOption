/// <summary>
/// Baseline: the price keeps the change of the last candle. A method that is not better than this one adds nothing.
/// </summary>
codeunit 50123 "SMA Last Candle Fcst" implements "SMA IForecast Method"
{
    Access = Internal;

    var
        ForecastMath: Codeunit "SMA Forecast Math";

    procedure Forecast(var ForecastContext: Codeunit "SMA Forecast Context"; Steps: Integer; var Points: List of [Decimal]; var Sigmas: List of [Decimal])
    var
        Series: List of [Decimal];
        Price: Decimal;
        Change: Decimal;
        StepSigma: Decimal;
        CurrentPosition: Integer;
        Step: Integer;
    begin
        Clear(Points);
        Clear(Sigmas);
        CurrentPosition := ForecastContext.Position();
        Series := ForecastContext.WindowCloses();
        if Series.Count() < 3 then
            exit;

        Price := ForecastContext.CloseAt(CurrentPosition);
        Change := Price - ForecastContext.CloseAt(CurrentPosition - 1);
        StepSigma := ForecastMath.ChangeStdDev(Series);
        for Step := 1 to Steps do begin
            Points.Add(Price + Change);
            Sigmas.Add(StepSigma * ForecastMath.Sqrt(Step));
        end;
    end;
}
