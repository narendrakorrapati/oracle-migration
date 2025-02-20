package com.narendra.controller;

import com.narendra.service.FlywayService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;

import java.util.Arrays;
import java.util.List;
import java.util.Scanner;
import java.util.stream.Collectors;

public class FlywayStartupCommandLineRunner implements CommandLineRunner {
    @Autowired
    private FlywayService flywayService;
    @Override
    public void run(String... args) throws Exception {
        try(Scanner scanner = new Scanner(System.in)) {
            // Get all schema names from the database
            List<String> allSchemas = flywayService.getSchemaNames();

            while (true) {
                System.out.println("\nSelect an option:");
                System.out.println("1. Migrate all schemas");
                System.out.println("2. Migrate specific schemas");
                System.out.println("3. Repair all schemas");
                System.out.println("4. Repair specific schemas");
                System.out.println("5. Exit");

                System.out.print("Enter your choice: ");
                int choice = scanner.nextInt();
                scanner.nextLine();  // Consume newline

                if (choice == 5) {
                    System.out.println("Exiting Flyway Command Line Tool.");
                    break;
                }

                List<String> selectedSchemas;
                if (choice == 2 || choice == 4) {
                    System.out.print("Enter schema names (comma-separated): ");
                    String input = scanner.nextLine();
                    selectedSchemas = Arrays.stream(input.split(","))
                            .map(String::trim)
                            //.filter(allSchemas::contains)
                            .collect(Collectors.toList());

                    if (selectedSchemas.isEmpty()) {
                        System.out.println("No valid schemas entered! Please try again.");
                        continue;
                    }
                } else {
                    selectedSchemas = allSchemas;
                }

                if(choice == 1 || choice == 2) {
                    System.out.println("Running Migrate for schemas: " + selectedSchemas);
                    flywayService.migrate(selectedSchemas);
                } else {
                    System.out.println("Running Repair for schemas: " + selectedSchemas);
                    flywayService.repair(selectedSchemas);
                }
            }
        }
    }
}
