package com.narendra.service;

import org.flywaydb.core.Flyway;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.stereotype.Service;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

@Service
public class FlywayService {
    @Value("${spring.flyway.locations}")
    private String[] flywayLocations;
    @Value("${spring.flyway.baseline-on-migrate}")
    private boolean baselineOnMigrate;
    @Value("${spring.flyway.baseline-version}")
    private String baselineVersion;
    @Autowired
    private DataSource dataSource;

    public List<String> getSchemaNames() {
        List<String> schemaNames = new ArrayList<>();
        try (Connection connection = dataSource.getConnection();
             Statement statement = connection.createStatement();
             ResultSet resultSet = statement.executeQuery("SELECT USERNAME FROM ALL_USERS WHERE USERNAME LIKE 'CUSTOMER%' ")) {

            while (resultSet.next()) {
                schemaNames.add(resultSet.getString("USERNAME"));
            }
        } catch (Exception e) {
            throw new RuntimeException("Error fetching schema names", e);
        }
        return schemaNames;
    }

    public void migrate(List<String> selectedSchemas) {
        for(String schema : selectedSchemas) {
            System.out.println("*****************Running Flyway Migration for Schema: " + schema + " ********************");
            Flyway flyway = getFlyway(schema);
            flyway.migrate();
        }
    }

    public void repair(List<String> selectedSchemas) {
        for(String schema : selectedSchemas) {
            System.out.println("*****************Running Flyway Repair for Schema: " + schema + " ********************");
            Flyway flyway = getFlyway(schema);
            flyway.repair();
        }
    }

    private Flyway getFlyway(String schema) {
        Flyway flyway = Flyway.configure()
                .dataSource(dataSource)
                .schemas(schema)
                .locations(flywayLocations)
                .baselineOnMigrate(baselineOnMigrate)
                .baselineVersion(baselineVersion)
                .load();
        return flyway;
    }
}
