/// <summary>
/// Average of the linear regression and the Holt damped trend forecasts.
/// </summary>
codeunit 50107 "SMA Ensemble Fcst" implements "SMA IForecast Method"
{
    Access = Internal;

    var
        LinearRegressionFcst: Codeunit "SMA Linear Regression Fcst";
        HoltDampedFcst: Codeunit "SMA Holt Damped Fcst";

    procedure Forecast(Series: List of [Decimal]; Steps: Integer; var Points: List of [Decimal]; var Sigmas: List of [Decimal])
    var
        LinearPoints: List of [Decimal];
        LinearSigmas: List of [Decimal];
        HoltPoints: List of [Decimal];
        HoltSigmas: List of [Decimal];
        Step: Integer;
    begin
        Clear(Points);
        Clear(Sigmas);
        LinearRegressionFcst.Forecast(Series, Steps, LinearPoints, LinearSigmas);
        HoltDampedFcst.Forecast(Series, Steps, HoltPoints, HoltSigmas);
        if (LinearPoints.Count() < Steps) or (HoltPoints.Count() < Steps) then
            exit;

        for Step := 1 to Steps do begin
            Points.Add((LinearPoints.Get(Step) + HoltPoints.Get(Step)) / 2);
            Sigmas.Add((LinearSigmas.Get(Step) + HoltSigmas.Get(Step)) / 2);
        end;
    end;
}
