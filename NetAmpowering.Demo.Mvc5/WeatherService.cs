using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using NetAmpowering.Observability.Interceptors;
using NetAmpowering.Observability.NHibernate;
using NHibernate;
using NHibernate.Cfg;
using NHibernate.Dialect;
using NHibernate.Driver;
using NHibernate.Mapping.ByCode;
using NHibernate.Mapping.ByCode.Conformist;
using NHibernate.Tool.hbm2ddl;

namespace NetAmpowering.Demo.Mvc5
{
    /// <summary>Weather forecast service, traced automatically via <c>TracedProxy</c> (one span per call).</summary>
    public interface IWeatherService
    {
        /// <summary>Returns the upcoming forecasts.</summary>
        /// <param name="days">Number of forecast days requested.</param>
        /// <returns>The requested forecasts.</returns>
        IList<Forecast> GetForecasts(int days);
    }

    /// <summary>NHibernate configuration of the demo: LocalDB database, mapping by code and traced driver.</summary>
    public static class NHibernateConfig
    {
        /// <summary>NHibernate session factory, created on first access.</summary>
        public static readonly ISessionFactory SessionFactory = Build();

        private const string Database = "NetAmpoweringDemoMvc5";
        private const string Server = @"Server=(localdb)\MSSQLLocalDB;Integrated Security=true;";

        private static ISessionFactory Build()
        {
            using (var connection = new SqlConnection(Server))
            {
                connection.Open();
                var cmd = connection.CreateCommand();
                cmd.CommandText = "IF DB_ID('" + Database + "') IS NULL CREATE DATABASE [" + Database + "]";
                cmd.ExecuteNonQuery();
            }

            var cfg = new Configuration();
            cfg.DataBaseIntegration(db =>
            {
                db.Dialect<MsSql2012Dialect>();
                db.Driver<SqlClientDriver>();
                db.ConnectionString = Server + "Database=" + Database + ";";
            });

            var mapper = new ModelMapper();
            mapper.AddMapping<ForecastMap>();
            cfg.AddMapping(mapper.CompileMappingForAllExplicitlyAddedEntities());

            // One line: replaces the driver with its traced version (one span per SQL command).
            cfg.AddNetAmpoweringTracing();

            new SchemaUpdate(cfg).Execute(false, true);
            return cfg.BuildSessionFactory();
        }
    }

    /// <summary>Manual composition: TracedProxy.Wrap creates one span per method call.</summary>
    public static class Services
    {
        /// <summary>Traced weather service: one span per method call.</summary>
        public static readonly IWeatherService Weather = TracedProxy.Wrap<IWeatherService>(new WeatherService());
    }

    /// <summary>Weather forecast of the demo.</summary>
    /// <remarks>NHibernate requires virtual members.</remarks>
    public class Forecast
    {
        /// <summary>Date of the forecast (<c>Date</c> column).</summary>
        public virtual DateTime ForecastDate { get; set; }

        /// <summary>Forecast identifier.</summary>
        public virtual int Id { get; set; }

        /// <summary>Summary of the weather.</summary>
        public virtual string Summary { get; set; }

        /// <summary>Temperature in degrees Celsius.</summary>
        public virtual int TemperatureC { get; set; }
    }

    /// <summary>NHibernate mapping of the <see cref="Forecast"/> entity.</summary>
    public class ForecastMap : ClassMapping<Forecast>
    {
        /// <summary>Declares the table, the identifier and the columns.</summary>
        public ForecastMap()
        {
            Table("Forecasts");
            Id(x => x.Id, m => m.Generator(Generators.Identity));
            Property(x => x.ForecastDate, m => m.Column("Date")); // colonne historique "Date"
            Property(x => x.TemperatureC);
            Property(x => x.Summary);
        }
    }

    /// <summary>Implementation of the weather service.</summary>
    public class WeatherService : IWeatherService
    {
        private static readonly string[] Summaries =
            {
                "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching",
            };

        /// <inheritdoc/>
        public IList<Forecast> GetForecasts(int days)
        {
            using (var session = NHibernateConfig.SessionFactory.OpenSession())
            {
                if (!session.Query<Forecast>().Any())
                {
                    using (var tx = session.BeginTransaction())
                    {
                        var rng = new Random(42);
                        for (var i = 1; i <= 15; i++)
                        {
                            session.Save(new Forecast
                            {
                                ForecastDate = DateTime.Today.AddDays(i),
                                TemperatureC = rng.Next(-20, 55),
                                Summary = Summaries[rng.Next(Summaries.Length)],
                            });
                        }

                        tx.Commit();
                    }
                }

                return session.Query<Forecast>().OrderBy(f => f.ForecastDate).Take(days).ToList();
            }
        }
    }
}
