using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Data.Entity;
using System.Data.Entity.Infrastructure;
using System.Data.Entity.SqlServer;
using System.Linq;
using NetAmpowering.Observability.Interceptors;

namespace NetAmpowering.Demo.WebApi2
{
    /// <summary>Weather forecast service, traced automatically via <c>TracedProxy</c> (one span per call).</summary>
    public interface IWeatherService
    {
        /// <summary>Returns the upcoming forecasts.</summary>
        /// <param name="days">Number of forecast days requested.</param>
        /// <returns>The requested forecasts.</returns>
        IList<Forecast> GetForecasts(int days);

        /// <summary>Returns a forecast from its identifier.</summary>
        /// <param name="id">Forecast identifier.</param>
        /// <returns>The forecast, or <c>null</c> if it does not exist.</returns>
        Forecast Find(int id);
    }

    /// <summary>Manual composition: TracedProxy.Wrap creates one span per method call.</summary>
    public static class Services
    {
        /// <summary>Traced weather service: one span per method call.</summary>
        public static readonly IWeatherService Weather = TracedProxy.Wrap<IWeatherService>(new WeatherService());
    }

    /// <summary>Weather forecast of the demo.</summary>
    public class Forecast
    {
        /// <summary>Date of the forecast.</summary>
        public DateTime Date { get; set; }

        /// <summary>Forecast identifier.</summary>
        [Key]
        public int Id { get; set; }

        /// <summary>Summary of the weather.</summary>
        public string Summary { get; set; }

        /// <summary>Temperature in degrees Celsius.</summary>
        public int TemperatureC { get; set; }
    }

    /// <summary>EF6 configuration in code (SQL Server LocalDB): no entityFramework block in web.config.</summary>
    public class DemoDbConfiguration : DbConfiguration
    {
        /// <summary>Configures the SQL Server provider and the LocalDB connection factory.</summary>
        public DemoDbConfiguration()
        {
            SetProviderServices("System.Data.SqlClient", SqlProviderServices.Instance);
            SetDefaultConnectionFactory(new LocalDbConnectionFactory("MSSQLLocalDB"));
        }
    }

    /// <summary>EF6 context of the demo.</summary>
    /// <remarks>The SQL commands of this context are traced by NetAmpowering.Observability.EntityFramework6.</remarks>
    [DbConfigurationType(typeof(DemoDbConfiguration))]
    public class DemoDbContext : DbContext
    {
        /// <summary>Initializes the context on the LocalDB database of the demo.</summary>
        public DemoDbContext()
            : base("NetAmpoweringDemoWebApi2")
        {
        }

        /// <summary>Forecasts table.</summary>
        public DbSet<Forecast> Forecasts { get; set; }
    }

    /// <summary>Implementation of the weather service.</summary>
    public class WeatherService : IWeatherService
    {
        private static readonly string[] Summaries =
            {
                "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching",
            };

        /// <inheritdoc/>
        public Forecast Find(int id)
        {
            using (var db = new DemoDbContext())
            {
                Seed(db);
                return db.Forecasts.FirstOrDefault(f => f.Id == id);
            }
        }

        /// <inheritdoc/>
        public IList<Forecast> GetForecasts(int days)
        {
            using (var db = new DemoDbContext())
            {
                Seed(db);
                return db.Forecasts.OrderBy(f => f.Date).Take(days).ToList();
            }
        }

        private static void Seed(DemoDbContext db)
        {
            if (db.Forecasts.Any())
            {
                return;
            }

            var rng = new Random(42);
            db.Forecasts.AddRange(Enumerable.Range(1, 15).Select(i => new Forecast
            {
                Date = DateTime.Today.AddDays(i),
                TemperatureC = rng.Next(-20, 55),
                Summary = Summaries[rng.Next(Summaries.Length)],
            }));
            db.SaveChanges();
        }
    }
}
