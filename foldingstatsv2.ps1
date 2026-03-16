# Hide the background PowerShell console
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0)

# Load the WPF framework
Add-Type -AssemblyName PresentationFramework

# Define the overlay GUI using XAML inside standard quotes
[xml]$xaml = '
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Folding@Home Stats Overlay" Height="220" Width="650"
        Background="#E6121212" WindowStartupLocation="CenterScreen"
        WindowStyle="None" AllowsTransparency="True" Topmost="True"
        FontFamily="Segoe UI Variable, Segoe UI" ResizeMode="NoResize">
    <Border BorderBrush="#44FFFFFF" BorderThickness="1" CornerRadius="8" Padding="15">
        <Grid>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,-5,-5,0">
                <Button Name="MinimizeButton" Content="&#x2212;" Width="24" Height="24" 
                        Background="Transparent" Foreground="#666666" BorderThickness="0" 
                        FontSize="16" Cursor="Hand" Margin="0,0,5,0" FontWeight="Bold" />
                <Button Name="CloseButton" Content="&#x2715;" Width="24" Height="24" 
                        Background="Transparent" Foreground="#666666" BorderThickness="0" 
                        FontSize="14" Cursor="Hand" />
            </StackPanel>

            <Grid Margin="0,15,0,0">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                
                <Grid Grid.Row="0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    
                    <StackPanel Grid.Column="0" Orientation="Horizontal">
                        <TextBox Name="UsernameInput" Width="140" Height="24" Background="#1A1A1A" Foreground="#FFFFFF" 
                                 BorderBrush="#555555" BorderThickness="1" Padding="4,0,4,0" 
                                 VerticalContentAlignment="Center" />
                        <Button Name="SetUserButton" Content="Set" Width="40" Height="24" Margin="5,0,0,0" 
                                Background="#333333" Foreground="#FFFFFF" BorderThickness="0" Cursor="Hand" />
                    </StackPanel>

                    <TextBlock Name="SessionChangeLabel" Grid.Column="1" Foreground="#CCCCCC" FontSize="16" 
                               Text="Waiting for initial data..." HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,25,0" />
                </Grid>
                           
                <TextBlock Name="ScoreLabel" Grid.Row="1" Foreground="#FFFFFF" FontSize="64" 
                           Text="Loading Points..." HorizontalAlignment="Center" VerticalAlignment="Center" FontWeight="Light" />
                           
                <TextBlock Name="PercentLabel" Grid.Row="2" Foreground="#E0E0E0" FontSize="26" 
                           Text="Top 0.000000% of users" HorizontalAlignment="Center" Margin="0,0,0,15" />
                           
                <Grid Grid.Row="3">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Name="UserRankLabel" Grid.Column="0" Foreground="#CCCCCC" FontSize="16" 
                               Text="Loading user..." HorizontalAlignment="Left" />
                    <TextBlock Name="NextUpdateLabel" Grid.Column="1" Foreground="#CCCCCC" FontSize="16" 
                               Text="Next update in ..." HorizontalAlignment="Right" />
                </Grid>
            </Grid>
        </Grid>
    </Border>
</Window>
'

# Read the XAML and build the window
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Allow dragging the borderless window anywhere by clicking the background
$window.Add_MouseLeftButtonDown({
    $this.DragMove()
})

# Connect our PowerShell variables to the XAML elements
$MinimizeButton = $window.FindName("MinimizeButton")
$CloseButton = $window.FindName("CloseButton")
$UsernameInput = $window.FindName("UsernameInput")
$SetUserButton = $window.FindName("SetUserButton")
$SessionChangeLabel = $window.FindName("SessionChangeLabel")
$ScoreLabel = $window.FindName("ScoreLabel")
$PercentLabel = $window.FindName("PercentLabel")
$UserRankLabel = $window.FindName("UserRankLabel")
$NextUpdateLabel = $window.FindName("NextUpdateLabel")

# Wire up the Window Control buttons
$CloseButton.Add_Click({ $window.Close() })
$CloseButton.Add_MouseEnter({ $CloseButton.Foreground = "#FFFFFF" })
$CloseButton.Add_MouseLeave({ $CloseButton.Foreground = "#666666" })

$MinimizeButton.Add_Click({ $window.WindowState = "Minimized" })
$MinimizeButton.Add_MouseEnter({ $MinimizeButton.Foreground = "#FFFFFF" })
$MinimizeButton.Add_MouseLeave({ $MinimizeButton.Foreground = "#666666" })

# Wire up the Set User button hover effects
$SetUserButton.Add_MouseEnter({ $SetUserButton.Background = "#444444" })
$SetUserButton.Add_MouseLeave({ $SetUserButton.Background = "#333333" })

# Handle saving and loading the username
$configFile = "$env:LOCALAPPDATA\FaHOverlayUser.txt"

if (Test-Path $configFile) {
    $UsernameInput.Text = (Get-Content $configFile).Trim()
} else {
    $UsernameInput.Text = "AndrewThomasThomas"
}

# Setup tracking variables
$script:currentUser = $UsernameInput.Text
$script:initialScore = $null
$script:countdown = 0
$script:updateInterval = 300 

# Function to pull data from the API
$UpdateStats = {
    $inputUser = $UsernameInput.Text.Trim()
    
    if ([string]::IsNullOrWhiteSpace($inputUser)) {
        $ScoreLabel.Text = "Enter Username"
        return
    }

    # Reset session stats and save name if the user changed the name
    if ($inputUser -ne $script:currentUser) {
        $script:currentUser = $inputUser
        $script:initialScore = $null
        $SessionChangeLabel.Text = "Waiting for initial data..."
        
        # Save the new username to the config file
        Set-Content -Path $configFile -Value $script:currentUser
    }

    try {
        $url = "https://api.foldingathome.org/user/$script:currentUser"
        $response = Invoke-RestMethod -Uri $url -Method Get
        
        $currentScore = $response.score
        
        # Format and display the main score with the word Points
        $ScoreLabel.Text = "$('{0:N0}' -f $currentScore) Points"
        
        # Handle Session Changes math
        if ($null -eq $script:initialScore -or $script:initialScore -eq 0) {
            $script:initialScore = $currentScore
            $SessionChangeLabel.Text = "No score changes this session"
        } elseif ($currentScore -gt $script:initialScore) {
            $diff = $currentScore - $script:initialScore
            $SessionChangeLabel.Text = "Gained $('{0:N0}' -f $diff) points this session"
        }
        
        # Calculate Rank and Percentage
        $rankNum = $response.rank
        $rankStr = if ($rankNum) { '{0:N0}' -f $rankNum } else { "Unranked" }
        $UserRankLabel.Text = "$script:currentUser, Rank #$rankStr"
        
        $totalUsers = if ($response.users) { $response.users } elseif ($response.total_users) { $response.total_users } else { 3000000 }
        
        if ($rankNum -gt 0 -and $totalUsers -gt 0) {
            $topPercent = ($rankNum / $totalUsers) * 100
            $PercentLabel.Text = "Top {0:N6}% of users" -f $topPercent
        }
    }
    catch {
        $ScoreLabel.Text = "User Not Found"
        $SessionChangeLabel.Text = "Check username or network"
        $UserRankLabel.Text = "Waiting..."
    }
}

# Force an immediate update when the Set button is clicked
$SetUserButton.Add_Click({
    $NextUpdateLabel.Text = "Updating..."
    & $UpdateStats
    $script:countdown = $script:updateInterval
})

# Setup the 1-second countdown timer
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    if ($script:countdown -le 0) {
        $NextUpdateLabel.Text = "Updating..."
        & $UpdateStats
        $script:countdown = $script:updateInterval
    } else {
        $NextUpdateLabel.Text = "Next update in $($script:countdown)s"
        $script:countdown--
    }
})

# Start the timer and show the window
$timer.Start()
$window.ShowDialog() | Out-Null