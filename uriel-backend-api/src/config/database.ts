import { Sequelize } from 'sequelize';

const database = new Sequelize('your_database_name', 'your_username', 'your_password', {
  host: 'localhost',
  dialect: 'postgres', // or 'mysql', 'sqlite', 'mssql'
  logging: false, // Set to true to see SQL queries in the console
});

export default database;