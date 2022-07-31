# DAMG 6210 - Database Management & Database Design
### Team Number - 6

## Database purpose:

The purpose of this database is to maintain the data of a car rental service. It would contain
data related to rental cars, rental locations, customers, customer service, memberships,
bookings, payment information, maintenance and insurance data. The database will be used for
administrative and analysis purposes.

## Business Problems Addressed:

● Allow customers to book rental cars and manage their bookings

● Rental service should be able to serve the customers with the nearest available cars for
a specified time frame.

● Facilitate the rental agency to buy cars from different vendors.

● Determine maintenance of cars based on usage patterns

● Generate reports for business to analyze revenue which are aggregated over
membership types, car types, booking times etc..

## Business Rules:

● Customer can only look at the available cars after authentication

● Customers cannot book a car without verification and a valid membership.

● Customers can have only one active booking.

● Customer can have multiple(max 3) booking without overlap

● Rental Cars cannot have multiple active bookings at any point of time.

● Rental Cars should be picked up and dropped off at the same location.

● Rental Cars cannot be rented without taking insurance.

● Customers will incur late fees if the booking goes over the end time.

● Car maintenance records must be maintained.

● An employee can have only one customer service request associated with him/her.

● A car entry cannot be created without a valid vendor ID

## Design Requirements

● Use Crow's Foot Notation.

● Specify the primary key fields in each table by specifying PK beside the fields. Draw a
line between the fields of each table to show the relationships between each table. This
line should be pointed directly to the fields in each table that are used to form the
relationship.

● Specify which table is on the one side of the relationship by placing a one next to the
field where the line starts

● Specify which table is on the many sides of the relationship by placing a crow's feet
symbol next to the field where the line ends.

## ERD Diagram

![DAMG6210-Assignment2-FinalERD](https://user-images.githubusercontent.com/13203059/182037072-7c3eea8b-3325-454d-8ce0-07936e2c20b3.png)
