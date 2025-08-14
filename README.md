Project file (.NET Framework 4.8)
xml
Copy
Edit
<!-- YourProject.csproj (header trimmed for brevity) -->
<Project ToolsVersion="15.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props" Condition="Exists('$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props')" />
  <PropertyGroup>
    <Configuration Condition=" '$(Configuration)' == '' ">Debug</Configuration>
    <Platform Condition=" '$(Platform)' == '' ">AnyCPU</Platform>
    <ProjectGuid>{F8D53C8B-1C2F-4C90-84D9-5A4EFA1C5A6B}</ProjectGuid>
    <OutputType>WinExe</OutputType>
    <RootNamespace>YourProject</RootNamespace>
    <AssemblyName>YourProject</AssemblyName>
    <TargetFrameworkVersion>v4.8</TargetFrameworkVersion>
    <FileAlignment>512</FileAlignment>
    <AutoGenerateBindingRedirects>true</AutoGenerateBindingRedirects>
    <Deterministic>true</Deterministic>
  </PropertyGroup>
  <ItemGroup>
    <Reference Include="System" />
    <Reference Include="System.Core" />
    <Reference Include="Microsoft.CSharp" />
    <Reference Include="WindowsBase" />
    <Reference Include="PresentationCore" />
    <Reference Include="PresentationFramework" />
    <Reference Include="System.Data" />
    <Reference Include="System.Xml" />
  </ItemGroup>
  <ItemGroup>
    <ApplicationDefinition Include="App.xaml" />
    <Page Include="MainWindow.xaml" />
    <Compile Include="App.xaml.cs" />
    <Compile Include="MainWindow.xaml.cs" />
    <Compile Include="ViewModels\MainViewModel.cs" />
    <Compile Include="ViewModels\RowItemViewModel.cs" />
    <Compile Include="ViewModels\OracleStatsTooltipViewModel.cs" />
    <Compile Include="Services\IOracleStatsService.cs" />
    <Compile Include="Services\OracleStatsServiceStub.cs" />
    <Compile Include="Models\OracleStats.cs" />
    <Compile Include="Utilities\BoolToVisibilityConverter.cs" />
    <Compile Include="Utilities\InverseBoolToVisibilityConverter.cs" />
  </ItemGroup>
  <Import Project="$(MSBuildToolsPath)\Microsoft.CSharp.targets" />
</Project>
App.xaml
xml
Copy
Edit
<Application x:Class="YourProject.App"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             StartupUri="MainWindow.xaml">
    <Application.Resources>
        <local:BoolToVisibilityConverter x:Key="BoolToVisibility" xmlns:local="clr-namespace:YourProject.Utilities"/>
        <local:InverseBoolToVisibilityConverter x:Key="InverseBoolToVisibility" xmlns:local="clr-namespace:YourProject.Utilities"/>
    </Application.Resources>
</Application>
App.xaml.cs
csharp
Copy
Edit
using System.Windows;

namespace YourProject
{
    public partial class App : Application { }
}
MainWindow.xaml
xml
Copy
Edit
<Window x:Class="YourProject.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:vm="clr-namespace:YourProject.ViewModels"
        mc:Ignorable="d"
        Title="Demo - Oracle Stats Tooltip" Height="450" Width="800">
    <Window.DataContext>
        <!-- Construct the MainViewModel in code-behind so we can inject the service. -->
        <vm:MainViewModel x:Name="DesignVM" d:IsDesignTimeCreatable="True"/>
    </Window.DataContext>

    <Grid Margin="16">
        <DataGrid ItemsSource="{Binding Rows}" AutoGenerateColumns="False"
                  HeadersVisibility="Column" IsReadOnly="True">
            <!-- Column 0 (hover here to see tooltip) -->
            <DataGridTemplateColumn Header="Item">
                <DataGridTemplateColumn.CellTemplate>
                    <DataTemplate>
                        <TextBlock Text="{Binding Name}" Padding="6">
                            <TextBlock.ToolTip>
                                <!-- Per-row tooltip -->
                                <ToolTip StaysOpen="False"
                                         Opened="ToolTip_OnOpened"
                                         Placement="Mouse"
                                         ToolTipService.InitialShowDelay="200">
                                    <!-- Table-like layout -->
                                    <Border BorderBrush="#CCC" BorderThickness="1" Padding="0" Background="White">
                                        <StackPanel>
                                            <!-- Title -->
                                            <TextBlock Text="Oracle Stats"
                                                       FontWeight="Bold"
                                                       FontSize="14"
                                                       Padding="10"
                                                       Background="#f0f0f0"/>
                                            <!-- Table -->
                                            <Grid Margin="0">
                                                <Grid.RowDefinitions>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="*"/>
                                                </Grid.RowDefinitions>
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition Width="*"/>
                                                    <ColumnDefinition Width="100"/>
                                                    <ColumnDefinition Width="100"/>
                                                </Grid.ColumnDefinitions>

                                                <!-- Header Row -->
                                                <Border Grid.Row="0" Grid.Column="0" BorderBrush="#ccc" BorderThickness="0,1,1,1" Background="#fafafa">
                                                    <TextBlock Text="" Padding="8" TextAlignment="Center"/>
                                                </Border>
                                                <Border Grid.Row="0" Grid.Column="1" BorderBrush="#ccc" BorderThickness="0,1,1,1" Background="#fafafa">
                                                    <TextBlock Text="Team1" Padding="8" TextAlignment="Center"/>
                                                </Border>
                                                <Border Grid.Row="0" Grid.Column="2" BorderBrush="#ccc" BorderThickness="0,1,1,1" Background="#fafafa">
                                                    <TextBlock Text="Team2" Padding="8" TextAlignment="Center"/>
                                                </Border>

                                                <!-- Loading / Error overlays -->
                                                <Grid Grid.RowSpan="6" Grid.ColumnSpan="3" Background="#66FFFFFF" Visibility="{Binding TooltipVM.IsLoading, Converter={StaticResource BoolToVisibility}}">
                                                    <TextBlock Text="Loading..." FontStyle="Italic" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                                                </Grid>
                                                <Grid Grid.RowSpan="6" Grid.ColumnSpan="3" Background="#88FFEEEE" Visibility="{Binding TooltipVM.HasError, Converter={StaticResource BoolToVisibility}}">
                                                    <TextBlock Text="{Binding TooltipVM.ErrorMessage}" Foreground="Red" TextWrapping="Wrap" Margin="8" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                                                </Grid>

                                                <!-- ELO -->
                                                <Border Grid.Row="1" Grid.Column="0" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="ELO" Padding="8"/></Border>
                                                <Border Grid.Row="1" Grid.Column="1" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="{Binding TooltipVM.Stats.Team1Elo}" Padding="8" TextAlignment="Center"/></Border>
                                                <Border Grid.Row="1" Grid.Column="2" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="{Binding TooltipVM.Stats.Team2Elo}" Padding="8" TextAlignment="Center"/></Border>

                                                <!-- No. of Matches -->
                                                <Border Grid.Row="2" Grid.Column="0" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="No. of Matches" Padding="8"/></Border>
                                                <Border Grid.Row="2" Grid.Column="1" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="{Binding TooltipVM.Stats.Team1Matches}" Padding="8" TextAlignment="Center"/></Border>
                                                <Border Grid.Row="2" Grid.Column="2" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="{Binding TooltipVM.Stats.Team2Matches}" Padding="8" TextAlignment="Center"/></Border>

                                                <!-- No. of H2H's -->
                                                <Border Grid.Row="3" Grid.Column="0" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="No. of H2H's" Padding="8"/></Border>
                                                <Border Grid.Row="3" Grid.Column="1" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="{Binding TooltipVM.Stats.Team1H2H}" Padding="8" TextAlignment="Center"/></Border>
                                                <Border Grid.Row="3" Grid.Column="2" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="{Binding TooltipVM.Stats.Team2H2H}" Padding="8" TextAlignment="Center"/></Border>

                                                <!-- Last H2H Date -->
                                                <Border Grid.Row="4" Grid.Column="0" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="Last H2H Date" Padding="8"/></Border>
                                                <Border Grid.Row="4" Grid.Column="1" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="{Binding TooltipVM.Stats.Team1LastH2HDate, StringFormat=\{0:dd/MM/yyyy\}}" Padding="8" TextAlignment="Center"/></Border>
                                                <Border Grid.Row="4" Grid.Column="2" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="{Binding TooltipVM.Stats.Team2LastH2HDate, StringFormat=\{0:dd/MM/yyyy\}}" Padding="8" TextAlignment="Center"/></Border>

                                                <!-- Past 30 H2H Avg -->
                                                <Border Grid.Row="5" Grid.Column="0" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="Past 30 H2H Avg" Padding="8"/></Border>
                                                <Border Grid.Row="5" Grid.Column="1" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="{Binding TooltipVM.Stats.Team1Past30Avg}" Padding="8" TextAlignment="Center"/></Border>
                                                <Border Grid.Row="5" Grid.Column="2" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="{Binding TooltipVM.Stats.Team2Past30Avg}" Padding="8" TextAlignment="Center"/></Border>

                                                <!-- Past 5 H2H Avg -->
                                                <Border Grid.Row="6" Grid.Column="0" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="Past 5 H2H Avg" Padding="8"/></Border>
                                                <Border Grid.Row="6" Grid.Column="1" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="{Binding TooltipVM.Stats.Team1Past5Avg}" Padding="8" TextAlignment="Center"/></Border>
                                                <Border Grid.Row="6" Grid.Column="2" BorderBrush="#ccc" BorderThickness="0,0,1,1"><TextBlock Text="{Binding TooltipVM.Stats.Team2Past5Avg}" Padding="8" TextAlignment="Center"/></Border>
                                            </Grid>
                                        </StackPanel>
                                    </Border>
                                </ToolTip>
                            </TextBlock.ToolTip>
                        </TextBlock>
                    </DataTemplate>
                </DataGridTemplateColumn.CellTemplate>
            </DataGridTemplateColumn>

            <!-- More columns just for demo -->
            <DataGridTextColumn Header="Other Column" Binding="{Binding SomeValue}" />
        </DataGrid>
    </Grid>
</Window>
MainWindow.xaml.cs
csharp
Copy
Edit
using System.Windows;
using System.Windows.Controls;
using YourProject.Services;
using YourProject.ViewModels;

namespace YourProject
{
    public partial class MainWindow : Window
    {
        private readonly MainViewModel _vm;

        public MainWindow()
        {
            InitializeComponent();

            // Inject the service (replace OracleStatsServiceStub with a real SQL service later)
            IOracleStatsService service = new OracleStatsServiceStub();
            _vm = new MainViewModel(service);

            DataContext = _vm;
        }

        // Runs per-row when its tooltip is opened
        private async void ToolTip_OnOpened(object sender, RoutedEventArgs e)
        {
            var fe = sender as FrameworkElement;
            if (fe == null) return;

            // Each row’s DataContext is RowItemViewModel
            var row = fe.DataContext as RowItemViewModel;
            if (row == null) return;

            // Load (or refresh) the data for this row’s tooltip
            await row.TooltipVM.LoadAsync(row.Id);
        }
    }
}
Models/OracleStats.cs
csharp
Copy
Edit
using System;

namespace YourProject.Models
{
    public class OracleStats
    {
        public int Team1Elo { get; set; }
        public int Team2Elo { get; set; }

        public int Team1Matches { get; set; }
        public int Team2Matches { get; set; }

        public int Team1H2H { get; set; }
        public int Team2H2H { get; set; }

        public DateTime Team1LastH2HDate { get; set; }
        public DateTime Team2LastH2HDate { get; set; }

        public int Team1Past30Avg { get; set; }
        public int Team2Past30Avg { get; set; }

        public int Team1Past5Avg { get; set; }
        public int Team2Past5Avg { get; set; }
    }
}
Services/IOracleStatsService.cs
csharp
Copy
Edit
using System.Threading;
using System.Threading.Tasks;
using YourProject.Models;

namespace YourProject.Services
{
    public interface IOracleStatsService
    {
        Task<OracleStats> GetOracleStatsAsync(int keyId, CancellationToken ct);
    }
}
Services/OracleStatsServiceStub.cs (seed/sample data)
csharp
Copy
Edit
using System;
using System.Threading;
using System.Threading.Tasks;
using YourProject.Models;

namespace YourProject.Services
{
    // Replace this with a real SQL SP call later (example shown in comment)
    public class OracleStatsServiceStub : IOracleStatsService
    {
        public Task<OracleStats> GetOracleStatsAsync(int keyId, CancellationToken ct)
        {
            // Simulate different data per key
            int offset = (keyId % 3) * 10;

            var stats = new OracleStats
            {
                Team1Elo = 100 + offset,
                Team2Elo = 100 + offset,
                Team1Matches = 25 + offset,
                Team2Matches = 50 + offset,
                Team1H2H = 10,
                Team2H2H = 10,
                Team1LastH2HDate = new DateTime(2025, 8, 14),
                Team2LastH2HDate = new DateTime(2025, 8, 14),
                Team1Past30Avg = 90,
                Team2Past30Avg = 90,
                Team1Past5Avg = 50,
                Team2Past5Avg = 50
            };

            return Task.FromResult(stats);
        }
    }

    /*
    // Example of a .NET Framework 4.8 ADO.NET call to a stored procedure:
    using System.Data;
    using System.Data.SqlClient;
    public class OracleStatsServiceSql : IOracleStatsService
    {
        private readonly string _connString;
        public OracleStatsServiceSql(string connString) { _connString = connString; }

        public async Task<OracleStats> GetOracleStatsAsync(int keyId, CancellationToken ct)
        {
            var result = new OracleStats();
            using (var conn = new SqlConnection(_connString))
            using (var cmd = new SqlCommand("dbo.usp_GetOracleStats", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@KeyId", SqlDbType.Int) { Value = keyId });
                await conn.OpenAsync(ct).ConfigureAwait(false);

                using (var reader = await cmd.ExecuteReaderAsync(ct).ConfigureAwait(false))
                {
                    if (await reader.ReadAsync(ct).ConfigureAwait(false))
                    {
                        result.Team1Elo = reader.GetInt32(reader.GetOrdinal("Team1Elo"));
                        result.Team2Elo = reader.GetInt32(reader.GetOrdinal("Team2Elo"));
                        // ... map all other columns similarly
                    }
                }
            }
            return result;
        }
    }
    */
}
ViewModels/OracleStatsTooltipViewModel.cs
csharp
Copy
Edit
using System;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Threading;
using System.Threading.Tasks;
using YourProject.Models;
using YourProject.Services;

namespace YourProject.ViewModels
{
    public class OracleStatsTooltipViewModel : INotifyPropertyChanged
    {
        private readonly IOracleStatsService _service;
        private CancellationTokenSource _cts;

        public OracleStatsTooltipViewModel(IOracleStatsService service)
        {
            _service = service;
        }

        private OracleStats _stats;
        public OracleStats Stats
        {
            get => _stats;
            private set { _stats = value; OnPropertyChanged(); }
        }

        private bool _isLoading;
        public bool IsLoading
        {
            get => _isLoading;
            private set { _isLoading = value; OnPropertyChanged(); }
        }

        private bool _hasError;
        public bool HasError
        {
            get => _hasError;
            private set { _hasError = value; OnPropertyChanged(); }
        }

        private string _errorMessage;
        public string ErrorMessage
        {
            get => _errorMessage;
            private set { _errorMessage = value; OnPropertyChanged(); }
        }

        public async Task LoadAsync(int keyId)
        {
            _cts?.Cancel();
            _cts = new CancellationTokenSource();

            IsLoading = true;
            HasError = false;
            ErrorMessage = null;

            try
            {
                var data = await _service.GetOracleStatsAsync(keyId, _cts.Token).ConfigureAwait(false);
                Stats = data;
            }
            catch (Exception ex)
            {
                HasError = true;
                ErrorMessage = ex.Message;
            }
            finally
            {
                IsLoading = false;
            }
        }

        public event PropertyChangedEventHandler PropertyChanged;
        private void OnPropertyChanged([CallerMemberName] string n = null) =>
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(n));
    }
}
ViewModels/RowItemViewModel.cs
csharp
Copy
Edit
using System.ComponentModel;
using System.Runtime.CompilerServices;
using YourProject.Services;

namespace YourProject.ViewModels
{
    public class RowItemViewModel : INotifyPropertyChanged
    {
        public int Id { get; }
        public string Name { get; }
        public int SomeValue { get; }

        public OracleStatsTooltipViewModel TooltipVM { get; }

        public RowItemViewModel(int id, string name, int someValue, IOracleStatsService service)
        {
            Id = id;
            Name = name;
            SomeValue = someValue;
            TooltipVM = new OracleStatsTooltipViewModel(service);
        }

        public event PropertyChangedEventHandler PropertyChanged;
        private void OnPropertyChanged([CallerMemberName] string n = null) =>
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(n));
    }
}
ViewModels/MainViewModel.cs (seed rows)
csharp
Copy
Edit
using System.Collections.ObjectModel;
using YourProject.Services;

namespace YourProject.ViewModels
{
    public class MainViewModel
    {
        public ObservableCollection<RowItemViewModel> Rows { get; }

        public MainViewModel() { } // design-time

        public MainViewModel(IOracleStatsService service)
        {
            Rows = new ObservableCollection<RowItemViewModel>
            {
                new RowItemViewModel(101, "Fixture 101", 1, service),
                new RowItemViewModel(102, "Fixture 102", 2, service),
                new RowItemViewModel(103, "Fixture 103", 3, service),
                new RowItemViewModel(104, "Fixture 104", 4, service),
            };
        }
    }
}
Utilities/BoolToVisibilityConverter.cs
csharp
Copy
Edit
using System;
using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace YourProject.Utilities
{
    [ValueConversion(typeof(bool), typeof(Visibility))]
    public class BoolToVisibilityConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            bool flag = value is bool b && b;
            return flag ? Visibility.Visible : Visibility.Collapsed;
        }

        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
            => (value is Visibility v) && v == Visibility.Visible;
    }
}
Utilities/InverseBoolToVisibilityConverter.cs
csharp
Copy
Edit
using System;
using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace YourProject.Utilities
{
    public class InverseBoolToVisibilityConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            bool flag = value is bool b && b;
            return flag ? Visibility.Collapsed : Visibility.Visible;
        }

        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
            => !((value is Visibility v) && v == Visibility.Visible);
    }
}
How it behaves
Hover over column 0 (“Item”) for any row → tooltip opens.

The tooltip title is “Oracle Stats” (static).

The table rows are exactly:

ELO

No. of Matches

No. of H2H’s

Last H2H Date

Past 30 H2H Avg

Past 5 H2H Avg

Team1 / Team2 values are bound to TooltipVM.Stats.* and are loaded on demand when the tooltip opens.

Replace OracleStatsServiceStub with OracleStatsServiceSql (commented example) to call your stored procedure.

If you want this tooltip to show over a different column or control, just move the <ToolTip> to that element (the bindings will still work because they use the row’s DataContext).
