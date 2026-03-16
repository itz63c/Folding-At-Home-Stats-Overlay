# Hide the background PowerShell console
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0)

# Load the required frameworks
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Drawing

# Define the overlay GUI using XAML
[xml]$xaml = '
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Folding@Home Stats Overlay" Height="260" Width="650"
        Background="#E6121212" WindowStartupLocation="CenterScreen"
        WindowStyle="None" AllowsTransparency="True" Topmost="True"
        FontFamily="Segoe UI Variable, Segoe UI" ResizeMode="NoResize">
    <Border BorderBrush="#44FFFFFF" BorderThickness="1" CornerRadius="8" Padding="15">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="20"/>
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
                
                <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                    <Image Name="HeaderIcon" Width="24" Height="24" Margin="0,0,10,0" />
                    <TextBlock Text="Folding@Home User Statistics" Foreground="#FFFFFF" FontSize="18" FontWeight="SemiBold" VerticalAlignment="Center" />
                </StackPanel>

                <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                    <CheckBox Name="TopmostToggle" Content="Pin to top" Foreground="#CCCCCC" 
                              VerticalAlignment="Center" Margin="0,0,15,0" IsChecked="True" Cursor="Hand">
                        <CheckBox.Template>
                            <ControlTemplate TargetType="CheckBox">
                                <StackPanel Orientation="Horizontal" Background="Transparent">
                                    <TextBlock Text="{TemplateBinding Content}" Foreground="{TemplateBinding Foreground}" 
                                               VerticalAlignment="Center" Margin="0,0,8,0" FontSize="14"/>
                                    <Border x:Name="SwitchBorder" Width="36" Height="20" CornerRadius="10" 
                                            Background="#333333" BorderThickness="1" BorderBrush="#555555" VerticalAlignment="Center">
                                        <Ellipse x:Name="Knob" Width="12" Height="12" Fill="#888888" 
                                                 Margin="3,0,0,0" HorizontalAlignment="Left" />
                                    </Border>
                                </StackPanel>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsChecked" Value="True">
                                        <Setter TargetName="SwitchBorder" Property="Background" Value="#0067C0" />
                                        <Setter TargetName="SwitchBorder" Property="BorderBrush" Value="#0067C0" />
                                        <Setter TargetName="Knob" Property="Fill" Value="#FFFFFF" />
                                        <Setter TargetName="Knob" Property="HorizontalAlignment" Value="Right" />
                                        <Setter TargetName="Knob" Property="Margin" Value="0,0,3,0" />
                                    </Trigger>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter TargetName="SwitchBorder" Property="BorderBrush" Value="#AAAAAA" />
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </CheckBox.Template>
                    </CheckBox>

                    <Button Name="MinimizeButton" Content="&#x2212;" Width="24" Height="24" 
                            Background="Transparent" Foreground="#666666" BorderThickness="0" 
                            FontSize="16" Cursor="Hand" Margin="0,0,5,0" FontWeight="Bold" />
                    <Button Name="CloseButton" Content="&#x2715;" Width="24" Height="24" 
                            Background="Transparent" Foreground="#666666" BorderThickness="0" 
                            FontSize="14" Cursor="Hand" />
                </StackPanel>
            </Grid>

            <Grid Grid.Row="2">
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
                           Text="Waiting for initial data..." HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,5,0" />
            </Grid>
                       
            <TextBlock Name="ScoreLabel" Grid.Row="3" Foreground="#FFFFFF" FontSize="64" 
                       Text="Loading Points..." HorizontalAlignment="Center" VerticalAlignment="Center" FontWeight="Light" />
                       
            <TextBlock Name="PercentLabel" Grid.Row="4" Foreground="#E0E0E0" FontSize="26" 
                       Text="Top 0.000000% of users" HorizontalAlignment="Center" Margin="0,0,0,15" />
                       
            <Grid Grid.Row="5">
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
$HeaderIcon = $window.FindName("HeaderIcon")
$TopmostToggle = $window.FindName("TopmostToggle")
$MinimizeButton = $window.FindName("MinimizeButton")
$CloseButton = $window.FindName("CloseButton")
$UsernameInput = $window.FindName("UsernameInput")
$SetUserButton = $window.FindName("SetUserButton")
$SessionChangeLabel = $window.FindName("SessionChangeLabel")
$ScoreLabel = $window.FindName("ScoreLabel")
$PercentLabel = $window.FindName("PercentLabel")
$UserRankLabel = $window.FindName("UserRankLabel")
$NextUpdateLabel = $window.FindName("NextUpdateLabel")

# Extract the icon from the currently running executable
try {
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($exePath)
    $bitmap = $icon.ToBitmap()
    $memoryStream = New-Object System.IO.MemoryStream
    $bitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)
    $memoryStream.Position = 0
    $bitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage
    $bitmapImage.BeginInit()
    $bitmapImage.StreamSource = $memoryStream
    $bitmapImage.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bitmapImage.EndInit()
    $HeaderIcon.Source = $bitmapImage
} catch {
    # If icon extraction fails, it fails silently and leaves the image block empty
}

# Wire up the Window Control buttons
$CloseButton.Add_Click({ $window.Close() })
$CloseButton.Add_MouseEnter({ $CloseButton.Foreground = "#FFFFFF" })
$CloseButton.Add_MouseLeave({ $CloseButton.Foreground = "#666666" })

$MinimizeButton.Add_Click({ $window.WindowState = "Minimized" })
$MinimizeButton.Add_MouseEnter({ $MinimizeButton.Foreground = "#FFFFFF" })
$MinimizeButton.Add_MouseLeave({ $MinimizeButton.Foreground = "#666666" })

# Wire up the Topmost Toggle Checkbox
$TopmostToggle.Add_Checked({ $window.Topmost = $true })
$TopmostToggle.Add_Unchecked({ $window.Topmost = $false })

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