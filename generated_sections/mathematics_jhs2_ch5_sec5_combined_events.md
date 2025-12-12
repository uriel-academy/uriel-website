## Learning Objectives
After completing this section, students will be able to:
1. Understand the concept of combined events and their probabilities
2. Calculate the probability of the union of two events using the addition rule
3. Determine the probability of the intersection of two events using the multiplication rule
4. Solve real-life problems involving combined events and their probabilities

## Introduction
In our daily lives, we often encounter situations where we need to calculate the likelihood of multiple events occurring together or separately. For example, a market trader in Kumasi may want to know the probability of selling both plantains and yams on a given day, or a student preparing for the BECE exam might be interested in the chances of passing both the Mathematics and English papers. Understanding how to calculate the probabilities of combined events is crucial for making informed decisions and solving real-world problems.

In this section, we will explore the concept of combined events and learn how to calculate their probabilities using the addition and multiplication rules. By mastering these techniques, you will be well-equipped to tackle various probability questions in the BECE exam and apply your knowledge to everyday situations involving chance and uncertainty.

## Main Content
### Union of Two Events (Addition Rule)
The **union** of two events, denoted as A ∪ B, is the event that occurs when either event A or event B (or both) happens. The probability of the union of two events A and B is given by the addition rule:

P(A ∪ B) = P(A) + P(B) - P(A ∩ B)

where P(A ∩ B) is the probability of the intersection of events A and B (the event that both A and B occur simultaneously).

If events A and B are **mutually exclusive** (they cannot occur at the same time), then P(A ∩ B) = 0, and the addition rule simplifies to:

P(A ∪ B) = P(A) + P(B)

| Property | Formula |
|----------|---------|
| Union of Two Events | P(A ∪ B) = P(A) + P(B) - P(A ∩ B) |
| Union of Mutually Exclusive Events | P(A ∪ B) = P(A) + P(B) |

### Intersection of Two Events (Multiplication Rule)
The **intersection** of two events, denoted as A ∩ B, is the event that occurs when both event A and event B happen simultaneously. The probability of the intersection of two events A and B is given by the multiplication rule:

P(A ∩ B) = P(A) × P(B|A)

where P(B|A) is the **conditional probability** of event B occurring given that event A has already occurred.

If events A and B are **independent** (the occurrence of one event does not affect the probability of the other event), then P(B|A) = P(B), and the multiplication rule simplifies to:

P(A ∩ B) = P(A) × P(B)

| Property | Formula |
|----------|---------|
| Intersection of Two Events | P(A ∩ B) = P(A) × P(B\|A) |
| Intersection of Independent Events | P(A ∩ B) = P(A) × P(B) |

### Venn Diagrams and Combined Events
Venn diagrams are a useful tool for visualizing the relationships between events and calculating probabilities of combined events.

[IMAGE: A Venn diagram showing the union and intersection of two events A and B, with the sample space S represented by a rectangle and events A and B represented by overlapping circles. Label the regions corresponding to P(A), P(B), P(A ∩ B), and P(A ∪ B).]

To calculate the probability of the union or intersection of events using a Venn diagram:
1. Identify the regions corresponding to the individual events and their intersection.
2. Add the probabilities of the relevant regions, taking care not to double-count the intersection if applicable.

### Solving Combined Event Problems
When solving problems involving combined events, follow these steps:
1. Identify the events and determine whether they are independent, mutually exclusive, or overlapping.
2. Choose the appropriate rule (addition or multiplication) based on the relationship between the events.
3. Calculate the probabilities of the individual events and their intersection (if required).
4. Substitute the values into the relevant formula and simplify to obtain the final probability.

## Worked Examples
1. Kofi, a mobile money agent in Accra, has a 60% chance of completing a transaction successfully on the first attempt and a 50% chance of completing it on the second attempt. What is the probability that Kofi will complete the transaction successfully on either the first or second attempt?

Solution:
- Let A be the event of completing the transaction on the first attempt, and B be the event of completing it on the second attempt.
- P(A) = 0.60 and P(B) = 0.50
- Since the attempts are independent, we can use the addition rule for the union of two events:
  P(A ∪ B) = P(A) + P(B) - P(A ∩ B)
- P(A ∩ B) = P(A) × P(B) (multiplication rule for independent events)
  P(A ∩ B) = 0.60 × 0.50 = 0.30
- Substitute the values into the addition rule:
  P(A ∪ B) = 0.60 + 0.50 - 0.30 = 0.80
Therefore, the probability that Kofi will complete the transaction successfully on either the first or second attempt is 0.80 or 80%.

2. A bag contains 4 red balls and 6 blue balls. If two balls are drawn at random without replacement, what is the probability of drawing a red ball and then a blue ball?

[IMAGE: A bag containing 4 red balls and 6 blue balls, with two balls being drawn sequentially without replacement.]

Solution:
- Let A be the event of drawing a red ball on the first draw, and B be the event of drawing a blue ball on the second draw.
- P(A) = 4/10 = 2/5 (there are 4 red balls out of a total of 10 balls)
- P(B|A) = 6/9 = 2/3 (after drawing a red ball, there are 6 blue balls out of the remaining 9 balls)
- Using the multiplication rule for dependent events:
  P(A ∩ B) = P(A) × P(B|A)
  P(A ∩ B) = (2/5) × (2/3) = 4/15
Therefore, the probability of drawing a red ball and then a blue ball is 4/15.

3. In a village near Tamale, the probability of a farmer growing maize is 0.75, and the probability of growing yams is 0.60. If the probability of growing both maize and yams is 0.50, what is the probability that a farmer grows either maize or yams?

Solution:
- Let A be the event of growing maize, and B be the event of growing yams.
- P(A) = 0.75, P(B) = 0.60, and P(A ∩ B) = 0.50
- Using the addition rule for the union of two events:
  P(A ∪ B) = P(A) + P(B) - P(A ∩ B)
  P(A ∪ B) = 0.75 + 0.60 - 0.50 = 0.85
Therefore, the probability that a farmer grows either maize or yams is 0.85 or 85%.

## Practice Problems
1. A spinning wheel has 8 equal sections, of which 3 are colored green and 5 are colored yellow. If the wheel is spun twice, what is the probability of getting green on both spins? (Answer: 9/64)

2. In a class of 40 students, 25 play football, and 20 play basketball. If 10 students play both sports, what is the probability that a randomly selected student plays either football or basketball? (Answer: 7/8)

3. A bag contains 3 red marbles, 4 blue marbles, and 5 green marbles. If two marbles are drawn at random with replacement, what is the probability of drawing a red marble and then a blue marble? (Answer: 1/6)

## Summary
- The union of two events A and B, denoted as A ∪ B, is the event that occurs when either A or B (or both) happens. The probability of the union is given by the addition rule: P(A ∪ B) = P(A) + P(B) - P(A ∩ B).
- The intersection of two events A and B, denoted as A ∩ B, is the event that occurs when both A and B happen simultaneously. The probability of the intersection is given by the multiplication rule: P(A ∩ B) = P(A) × P(B|A).
- If events A and B are mutually exclusive, then P(A ∩ B) = 0, and the addition rule simplifies to P(A ∪ B) = P(A) + P(B).
- If events A and B are independent, then P(B|A) = P(B), and the multiplication rule simplifies to P(A ∩ B) = P(A) × P(B).
- Venn diagrams can be used to visualize the relationships between events and calculate probabilities of combined events.
- When solving problems involving combined events, identify the events, determine their relationship, choose the appropriate rule, calculate the probabilities, and substitute the values into the relevant formula.

## Key Vocabulary/Formulas
| Term/Formula | Meaning/Use |
|--------------|-------------|
| Union (A ∪ B) | The event that occurs when either event A or event B (or both) happens |
| Intersection (A ∩ B) | The event that occurs when both event A and event B happen simultaneously |
| Addition Rule | P(A ∪ B) = P(A) + P(B) - P(A ∩ B) |
| Multiplication Rule | P(A ∩ B) = P(A) × P(B\|A) |
| Mutually Exclusive Events | Events that cannot occur at the same time; P(A ∩ B) = 0 |
| Independent Events | Events where the occurrence of one does not affect the probability of the other; P(B\|A) = P(B) |
| Conditional Probability (P(B\|A)) | The probability of event B occurring given that event A has already occurred |