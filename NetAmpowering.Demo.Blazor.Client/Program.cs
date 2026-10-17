using Microsoft.AspNetCore.Components.WebAssembly.Hosting;

var builder = WebAssemblyHostBuilder.CreateDefault(args);

builder.Services.AddWasmObservability(new Uri(builder.HostEnvironment.BaseAddress));

await builder.Build().RunAsync();
