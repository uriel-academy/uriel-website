# Chapter 4: Vectors and Transformations
## Section: Introduction to Vectors

## Learning Objectives
After completing this section, students will be able to:
1. Define vectors and understand their properties
2. Represent vectors graphically and algebraically
3. Perform basic vector operations (addition, subtraction, scalar multiplication)
4. Apply vectors to solve real-world problems

## Introduction
Vectors are an essential concept in mathematics that have numerous applications in everyday life. In Ghana, vectors can be used to solve problems related to various aspects of student life. For instance, when you go to the market to buy goods, you can use vectors to calculate the total distance you need to walk from one stall to another. Vectors can also be used to analyze the flow of money in mobile money transactions, helping you understand how funds move between different accounts. In farming, vectors are useful for measuring land areas and determining the most efficient paths for planting crops. Moreover, a solid understanding of vectors is crucial for success in the WAEC/BECE exams, as they are frequently tested in the mathematics section.

## Main Content
### What are Vectors?
A **vector** is a mathematical object that has both magnitude (length) and direction. Vectors are represented by arrows, with the length of the arrow indicating the magnitude and the arrowhead pointing in the direction of the vector. In contrast, **scalars** are quantities that have only magnitude, such as temperature or mass.

Vectors are denoted using boldface letters, such as **a** or **b**, or by placing an arrow above the letter, like $\vec{a}$ or $\vec{b}$.

### Representing Vectors
Vectors can be represented in two ways:
1. Graphically: As arrows in a coordinate plane
2. Algebraically: Using ordered pairs (for 2D vectors) or ordered triples (for 3D vectors)

For example, a vector $\vec{a}$ in a 2D plane can be represented as $\vec{a} = (x, y)$, where $x$ and $y$ are the horizontal and vertical components of the vector, respectively.

[IMAGE: A 2D coordinate plane with a vector $\vec{a}$ represented as an arrow from the origin to the point (3, 4). The horizontal and vertical components of the vector should be clearly labeled.]

### Vector Operations
There are three basic vector operations:
1. Addition
2. Subtraction
3. Scalar multiplication

#### Vector Addition
To add two vectors $\vec{a} = (x_1, y_1)$ and $\vec{b} = (x_2, y_2)$, add their corresponding components:

$\vec{a} + \vec{b} = (x_1 + x_2, y_1 + y_2)$

[IMAGE: A 2D coordinate plane with vectors $\vec{a}$ and $\vec{b}$ represented as arrows. Show the resultant vector $\vec{a} + \vec{b}$ as the diagonal of the parallelogram formed by the two vectors.]

#### Vector Subtraction
To subtract vector $\vec{b}$ from vector $\vec{a}$, subtract their corresponding components:

$\vec{a} - \vec{b} = (x_1 - x_2, y_1 - y_2)$

#### Scalar Multiplication
To multiply a vector $\vec{a}$ by a scalar $c$, multiply each component of the vector by the scalar:

$c\vec{a} = (cx_1, cy_1)$

Scalar multiplication can be used to change the magnitude of a vector or reverse its direction (when multiplied by a negative scalar).

Properties of Vector Operations
| Property | Addition | Multiplication |
|----------|----------|----------------|
| Commutative | $\vec{a} + \vec{b} = \vec{b} + \vec{a}$ | $c\vec{a} \neq \vec{a}c$ (not commutative) |
| Associative | $(\vec{a} + \vec{b}) + \vec{c} = \vec{a} + (\vec{b} + \vec{c})$ | $(cd)\vec{a} = c(d\vec{a})$ |
| Distributive | $c(\vec{a} + \vec{b}) = c\vec{a} + c\vec{b}$ | $(c + d)\vec{a} = c\vec{a} + d\vec{a}$ |

## Worked Examples
1. A farmer in Kumasi wants to measure the perimeter of his rectangular farm. He walks 200 meters east, then 150 meters north, then 200 meters west, and finally 150 meters south. Use vectors to calculate the total distance the farmer walked.

Solution:
Let the eastward direction be the positive x-axis and the northward direction be the positive y-axis.
- Step 1: Represent the farmer's walk using vectors.
  - $\vec{a}$ = walking 200 meters east = (200, 0)
  - $\vec{b}$ = walking 150 meters north = (0, 150)
  - $\vec{c}$ = walking 200 meters west = (-200, 0)
  - $\vec{d}$ = walking 150 meters south = (0, -150)

- Step 2: Add the vectors to find the total displacement.
  $\vec{a} + \vec{b} + \vec{c} + \vec{d} = (200, 0) + (0, 150) + (-200, 0) + (0, -150) = (0, 0)$

- Step 3: Calculate the total distance walked.
  Total distance = $|\vec{a}| + |\vec{b}| + |\vec{c}| + |\vec{d}|$
                 = 200 + 150 + 200 + 150
                 = 700 meters

Therefore, the farmer walked a total distance of 700 meters.

2. Adwoa sends GH₵500 to Kofi via mobile money. Kofi then sends GH₵300 to Ama, who in turn sends GH₵200 back to Adwoa. Represent this transaction using vectors and find the net amount each person received.

Solution:
Let Adwoa be at the origin (0, 0), Kofi at (1, 0), and Ama at (2, 0).
- Step 1: Represent the transactions using vectors.
  - $\vec{a}$ = Adwoa sends GH₵500 to Kofi = (500, 0)
  - $\vec{b}$ = Kofi sends GH₵300 to Ama = (300, 0)
  - $\vec{c}$ = Ama sends GH₵200 back to Adwoa = (-200, 0)

- Step 2: Calculate the net amount each person received.
  - Adwoa: $-\vec{a} + \vec{c} = (-500, 0) + (-200, 0) = (-700, 0)$, meaning Adwoa sent a total of GH₵700.
  - Kofi: $\vec{a} - \vec{b} = (500, 0) - (300, 0) = (200, 0)$, meaning Kofi received a net amount of GH₵200.
  - Ama: $\vec{b} - \vec{c} = (300, 0) - (-200, 0) = (500, 0)$, meaning Ama received a net amount of GH₵500.

[IMAGE: A 1D number line with Adwoa at 0, Kofi at 1, and Ama at 2. Show the vectors representing the transactions between them.]

## Practice Problems
1. A boat sails 10 km north, then 15 km east, and finally 5 km south. Use vectors to find the boat's displacement from its starting point.

2. Kwame walks 300 meters east, then 200 meters north, and finally 100 meters west. His friend Akosua walks 150 meters north, then 250 meters east. Use vectors to determine who is farther from the starting point and by how much.

3. A plane flies from Accra to Kumasi, a displacement of (200 km, 50 km), and then from Kumasi to Tamale, a displacement of (-50 km, 150 km). Find the plane's total displacement and the distance traveled.

## Summary
- Vectors are mathematical objects with magnitude and direction, represented graphically as arrows or algebraically as ordered pairs or triples.
- Basic vector operations include addition, subtraction, and scalar multiplication.
- Vector operations have commutative, associative, and distributive properties.
- Vectors can be used to solve real-world problems involving distances, transactions, and displacements.
- A solid understanding of vectors is crucial for success in the WAEC/BECE mathematics exams.

## Key Vocabulary/Formulas

| Term/Formula | Meaning/Use |
|--------------|-------------|
| Vector | A mathematical object with magnitude and direction |
| Scalar | A quantity with only magnitude |
| $\vec{a} + \vec{b}$ | Vector addition: $(x_1 + x_2, y_1 + y_2)$ |
| $\vec{a} - \vec{b}$ | Vector subtraction: $(x_1 - x_2, y_1 - y_2)$ |
| $c\vec{a}$ | Scalar multiplication: $(cx_1, cy_1)$ |

Answers to Practice Problems:
1. Displacement = (10, 10)
2. Kwame's displacement = (200, 200), distance ≈ 282.84 meters; Akosua's displacement = (250, 150), distance ≈ 291.55 meters; Akosua is farther by about 8.71 meters
3. Total displacement = (150, 200), total distance ≈ 320.16 km