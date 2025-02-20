package com.narendra;

import org.flywaydb.core.Flyway;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class OracleMigrationApplication {

	public static void main(String[] args) {
		SpringApplication.run(OracleMigrationApplication.class, args);

	}

}
