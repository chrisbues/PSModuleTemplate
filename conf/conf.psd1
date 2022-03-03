# Required modules by PS version
@{
    psmodules = @(
        @{ name = 'AzureAdPreview'; Desktop = $true; Core = $false },
        @{ name = 'ExchangeOnlineManagement'; Desktop = $false; Core = $true },
        @{ name = 'Az.Accounts'; Desktop = $false; Core = $true },
        @{ name = 'Az.OperationalInsights'; Desktop = $false; Core = $true },
        @{ name = 'PSSqlite'; Desktop = $false; Core = $true },
        @{ name = 'ImportExcel'; Desktop = $false; Core = $true },
        @{ name = 'Microsoft.Graph'; Desktop = $false; Core = $true }
        );
    imports = @(
    @{ edition = 'Core'; public = '$_.Name -like "*"'; private = '$_.Name -like "*"' },
    @{ edition = 'Desktop'; public = '$_.Name -like "*"'; private = '$_.Name -like "*"' }
    );
}