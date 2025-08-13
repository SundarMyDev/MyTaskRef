# MyTaskRef
MyTaskRef


1) WPF ToolTip that loads data dynamically from a stored proc
Recommended approach: don’t hit the database on the UI thread or inside XAML triggers. Use MVVM: when the tooltip opens, kick off an async command that calls the stored proc, bind the result to the tooltip, and show a “Loading…” placeholder until it returns.

XAML (example)
xml
Copy
Edit
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:i="http://schemas.microsoft.com/expression/2010/interactivity"
    xmlns:local="clr-namespace:YourApp"
    DataContext="{Binding Main, Source={x:Static local:Locators.VM}}">
    <Grid>
        <TextBlock Text="Hover me">
            <TextBlock.ToolTip>
                <ToolTip StaysOpen="False" 
                         Opened="ToolTip_Opened">
                    <ContentControl Content="{Binding TooltipViewModel}">
                        <ContentControl.ContentTemplate>
                            <DataTemplate>
                                <Grid MinWidth="220" MinHeight="80">
                                    <Grid>
                                        <TextBlock Text="Loading..." 
                                                   Visibility="{Binding IsLoading, Converter={StaticResource BoolToVisibility}}"
                                                   FontStyle="Italic" Margin="6"/>
                                        <ItemsControl ItemsSource="{Binding Results}"
                                                      Visibility="{Binding IsLoading, Converter={StaticResource InverseBoolToVisibility}}">
                                            <ItemsControl.ItemTemplate>
                                                <DataTemplate>
                                                    <StackPanel Orientation="Vertical" Margin="6">
                                                        <!-- Bind to your proc columns -->
                                                        <TextBlock Text="{Binding ColumnA}"/>
                                                        <TextBlock Text="{Binding ColumnB}" Opacity="0.7"/>
                                                    </StackPanel>
                                                </DataTemplate>
                                            </ItemsControl.ItemTemplate>
                                        </ItemsControl>
                                        <TextBlock Foreground="Red" 
                                                   Text="{Binding ErrorMessage}" 
                                                   Visibility="{Binding HasError, Converter={StaticResource BoolToVisibility}}"
                                                   Margin="6"/>
                                    </Grid>
                                </Grid>
                            </DataTemplate>
                        </ContentControl.ContentTemplate>
                    </ContentControl>
                </ToolTip>
            </TextBlock.ToolTip>
        </TextBlock>
    </Grid>
</Window>
Code‑behind (only to trigger; keep logic in VM)
csharp
Copy
Edit
private async void ToolTip_Opened(object sender, RoutedEventArgs e)
{
    if (DataContext is MainViewModel vm)
    {
        // Optional: cancel previous request if still running
        await vm.TooltipViewModel.LoadAsync();
    }
}
ViewModel for the tooltip
csharp
Copy
Edit
public class TooltipVM : INotifyPropertyChanged
{
    private readonly IDataService _data;
    private CancellationTokenSource _cts;

    public ObservableCollection<MyRow> Results { get; } = new();
    public bool IsLoading { get; private set; }
    public bool HasError { get; private set; }
    public string ErrorMessage { get; private set; }

    public TooltipVM(IDataService data) => _data = data;

    public async Task LoadAsync()
    {
        _cts?.Cancel();
        _cts = new CancellationTokenSource();
        IsLoading = true; HasError = false; ErrorMessage = null;
        OnPropertyChanged(nameof(IsLoading)); OnPropertyChanged(nameof(HasError)); OnPropertyChanged(nameof(ErrorMessage));

        try
        {
            var rows = await _data.GetTooltipRowsAsync(_cts.Token); // calls stored proc
            Results.Clear();
            foreach (var r in rows) Results.Add(r);
        }
        catch (Exception ex)
        {
            HasError = true;
            ErrorMessage = ex.Message;
        }
        finally
        {
            IsLoading = false;
            OnPropertyChanged(nameof(IsLoading)); OnPropertyChanged(nameof(HasError)); OnPropertyChanged(nameof(ErrorMessage));
        }
    }

    public event PropertyChangedEventHandler PropertyChanged;
    private void OnPropertyChanged(string n) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(n));
}

public class MyRow
{
    public string ColumnA { get; set; }
    public string ColumnB { get; set; }
}
Data access (ADO.NET async; stored proc)
Use Microsoft.Data.SqlClient (modern) or System.Data.SqlClient (Framework 4.x). Async, parameterized, and with CommandType.StoredProcedure.

csharp
Copy
Edit
public interface IDataService
{
    Task<IList<MyRow>> GetTooltipRowsAsync(CancellationToken ct);
}

public sealed class SqlDataService : IDataService
{
    private readonly string _conn;
    public SqlDataService(string conn) => _conn = conn;

    public async Task<IList<MyRow>> GetTooltipRowsAsync(CancellationToken ct)
    {
        var list = new List<MyRow>();
        await using var conn = new Microsoft.Data.SqlClient.SqlConnection(_conn);
        await conn.OpenAsync(ct);

        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "dbo.usp_GetTooltipData";
        cmd.CommandType = CommandType.StoredProcedure;
        // cmd.Parameters.AddWithValue("@SomeId", id);

        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            list.Add(new MyRow
            {
                ColumnA = reader["ColumnA"] as string,
                ColumnB = reader["ColumnB"]?.ToString()
            });
        }
        return list;
    }
}
Tips

Show data quickly: consider caching results for a short TTL, and only refresh if stale.

Use ToolTipService.InitialShowDelay to avoid DB hits on accidental hovers.

If the tooltip should keep updating while open, start a DispatcherTimer or refresh command on Opened and stop on Closed.
