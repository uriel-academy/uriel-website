# Chapter 1: Advanced Number Operations
## Section: Number Bases

## Learning Objectives
By the end of this section, students will be able to:
1. Understand the concept of number bases and their use in different numeral systems.
2. Convert numbers between base 10 (decimal), base 2 (binary), and base 5 number systems.
3. Perform basic arithmetic operations (addition, subtraction, multiplication) in different bases.
4. Solve BECE-style questions involving number bases and their conversions.

## Introduction
In our daily lives, we use the decimal number system (base 10) for various activities, such as buying goods at the market, calculating prices in Ghana cedis, or even using mobile money for transactions. However, there are other number systems that use different bases, like binary (base 2) and base 5. Understanding these number systems is essential for computer science, coding, and various technological applications. As you prepare for your BECE exams, mastering number bases will not only help you solve mathematical problems but also develop a foundation for future learning in technology-related fields.

Imagine you are at a farm, and you need to count the number of chickens in different coops. You could use the decimal system, but what if you wanted to use a different number system to keep track of the counts? This is where understanding number bases becomes useful. By learning how to convert between different bases and perform arithmetic operations, you'll be equipped with valuable skills that can be applied in various situations, from everyday life to advanced mathematical concepts.

## Main Content
### Understanding Number Bases
A number base, also known as a radix, is the number of unique digits used to represent numbers in a numeral system. In the decimal system (base 10), we use ten digits: 0, 1, 2, 3, 4, 5, 6, 7, 8, and 9. However, in other bases, the number of digits and their values differ.

- **Binary (base 2)**: Uses two digits, 0 and 1.
- **Base 5**: Uses five digits, 0, 1, 2, 3, and 4.

### Converting Between Number Bases
To convert a number from one base to another, we use the following steps:

1. To convert from base 10 to another base:
   - Divide the decimal number by the target base repeatedly until the quotient becomes 0.
   - Write down the remainders in reverse order to obtain the number in the target base.

2. To convert from another base to base 10:
   - Multiply each digit by the base raised to the power of its place value (starting from 0 for the rightmost digit).
   - Sum up the products to obtain the decimal number.

### Arithmetic Operations in Different Bases
To perform arithmetic operations in different bases, we follow similar rules as in base 10, but with a limited set of digits. When the result of an operation exceeds the value of the highest digit in the base, we need to carry over to the next place value.

[IMAGE: Example of addition and multiplication in base 5, showing the carrying process]

## Worked Examples
### Example 1: Converting from base 10 to base 2
Convert the decimal number 25 to binary.

Solution:
Divide 25 by 2 repeatedly and write down the remainders in reverse order.

| Division | Quotient | Remainder |
|----------|----------|-----------|
| 25 ÷ 2   | 12       | 1         |
| 12 ÷ 2   | 6        | 0         |
| 6 ÷ 2    | 3        | 0         |
| 3 ÷ 2    | 1        | 1         |
| 1 ÷ 2    | 0        | 1         |

So, 25 in base 10 is equal to 11001 in base 2.

### Example 2: Converting from base 2 to base 10
Convert the binary number 1101 to decimal.

Solution:
Multiply each digit by 2 raised to the power of its place value and sum up the products.

| Place Value | Binary Digit | Calculation | Result |
|-------------|--------------|-------------|--------|
| 3           | 1            | 1 × 2^3     | 8      |
| 2           | 1            | 1 × 2^2     | 4      |
| 1           | 0            | 0 × 2^1     | 0      |
| 0           | 1            | 1 × 2^0     | 1      |

8 + 4 + 0 + 1 = 13

So, 1101 in base 2 is equal to 13 in base 10.

### Example 3: Addition in base 5
Perform the following addition in base 5: 123 + 244

[IMAGE: Vertical addition in base 5, showing the carrying process]

Solution:
  123
+ 244
-----
  412

So, 123 + 244 in base 5 is equal to 412 in base 5.

## Practice Problems
1. Convert the decimal number 42 to base 5.
2. Convert the base 5 number 1234 to decimal.
3. Perform the following subtraction in base 5: 432 - 214
4. Multiply the following numbers in base 2: 1011 × 101

(Answers: 1. 132; 2. 194; 3. 213; 4. 110111)

## Summary
- Number bases (radixes) represent the number of unique digits used in a numeral system.
- To convert from base 10 to another base, divide the decimal number by the target base repeatedly and write down the remainders in reverse order.
- To convert from another base to base 10, multiply each digit by the base raised to the power of its place value and sum up the products.
- Arithmetic operations in different bases follow similar rules as in base 10, with carrying over when the result exceeds the value of the highest digit in the base.

## Key Vocabulary/Formulas
| Term/Formula                        | Meaning/Use                                                                                               |
|-------------------------------------|-----------------------------------------------------------------------------------------------------------|
| Base (radix)                        | The number of unique digits used to represent numbers in a numeral system.                                |
| Binary (base 2)                     | A number system that uses two digits, 0 and 1.                                                           |
| Base 5                              | A number system that uses five digits, 0, 1, 2, 3, and 4.                                                |
| Place value                         | The value of a digit based on its position in a number.                                                   |
| Decimal to base n conversion        | Divide the decimal number by the target base repeatedly and write down the remainders in reverse order.  |
| Base n to decimal conversion        | Multiply each digit by the base raised to the power of its place value and sum up the products.          |