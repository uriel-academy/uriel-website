# Chapter 5: Data Analysis
## Section: Probability Trees

## Learning Objectives
By the end of this section, students will be able to:
1. Understand the concept of probability trees and their applications
2. Construct probability trees for simple and compound events
3. Calculate probabilities using probability trees
4. Solve real-life problems involving probability trees

## Introduction
Probability is a crucial concept in mathematics that helps us understand the likelihood of events occurring. In our daily lives, we often encounter situations where we need to make decisions based on the chances of certain outcomes. For example, when you go to the market to buy fruits, you might wonder what the probability is of selecting a ripe mango from a basket containing both ripe and unripe mangos. Or, when preparing for the BECE exams, you might want to know the probability of a particular topic appearing in the exam based on previous years' patterns.

Probability trees are a valuable tool for visualizing and calculating probabilities, especially when dealing with compound events. They help break down complex problems into simpler steps, making it easier to understand and solve them.

## Main Content
### What is a Probability Tree?
A **probability tree** is a diagram that represents the possible outcomes of a series of events. It consists of **branches** that represent each possible outcome, and each branch is labeled with the probability of that outcome occurring.

[IMAGE: A simple probability tree diagram showing the possible outcomes of flipping a coin twice, with branches labeled 'H' (heads) and 'T' (tails), and probabilities marked on each branch]

### Constructing Probability Trees
To construct a probability tree, follow these steps:
1. Identify the first event and list all its possible outcomes.
2. For each outcome of the first event, list all the possible outcomes of the second event.
3. Continue this process for all subsequent events.
4. Label each branch with the probability of that outcome occurring.

### Calculating Probabilities using Probability Trees
To calculate the probability of a specific outcome using a probability tree, follow these steps:
1. Identify the branches that lead to the desired outcome.
2. Multiply the probabilities along each branch to find the probability of that specific path.
3. If there are multiple paths leading to the desired outcome, add the probabilities of each path to find the total probability.

### Probability Tree Formulas
| Formula | Description |
|---------|-------------|
| P(A and B) = P(A) × P(B\|A) | The probability of events A and B occurring together |
| P(A or B) = P(A) + P(B) - P(A and B) | The probability of either event A or event B occurring |

## Worked Examples
1. Kofi has a bag containing 4 red marbles and 6 blue marbles. He draws two marbles from the bag without replacement. What is the probability that both marbles are red?

[IMAGE: A probability tree diagram showing the possible outcomes of drawing two marbles from the bag, with branches labeled 'R' (red) and 'B' (blue), and probabilities marked on each branch]

Step 1: Probability of drawing a red marble on the first draw = 4/10
Step 2: Probability of drawing a red marble on the second draw, given that the first marble was red = 3/9
Step 3: Probability of drawing two red marbles = 4/10 × 3/9 = 2/15

Therefore, the probability of drawing two red marbles is 2/15.

2. A mobile money service charges a fee of GH₵0.50 for transactions below GH₵100 and GH₵1.00 for transactions above GH₵100. If 60% of transactions are below GH₵100, find the expected average fee charged per transaction.

Step 1: Construct a probability tree
[IMAGE: A probability tree diagram showing the possible outcomes of a transaction, with branches labeled 'Below GH₵100' and 'Above GH₵100', and probabilities and fees marked on each branch]

Step 2: Calculate the probability of each outcome
P(Below GH₵100) = 0.60
P(Above GH₵100) = 1 - 0.60 = 0.40

Step 3: Calculate the expected average fee
Expected average fee = (0.60 × GH₵0.50) + (0.40 × GH₵1.00)
                     = GH₵0.30 + GH₵0.40
                     = GH₵0.70

Therefore, the expected average fee charged per transaction is GH₵0.70.

3. A farmer has two mango trees, A and B. Tree A has a 70% chance of bearing fruit, while tree B has an 80% chance. If both trees bear fruit, what is the probability of selecting a mango from tree A?

[IMAGE: A probability tree diagram showing the possible outcomes of the two trees bearing fruit, with branches labeled 'F' (fruit) and 'N' (no fruit), and probabilities marked on each branch]

Step 1: Probability of both trees bearing fruit = 0.70 × 0.80 = 0.56
Step 2: If both trees bear fruit, the probability of selecting a mango from tree A = 1/2 = 0.50

Therefore, the probability of selecting a mango from tree A, given that both trees bear fruit, is 0.50.

## Practice Problems
1. A fair die is rolled twice. What is the probability of getting a sum of 7 on the two rolls?
2. Ama has a box containing 3 red pens, 5 blue pens, and 2 green pens. She draws two pens from the box without replacement. What is the probability that both pens are blue?
3. In a school, 60% of students play football, and 40% of students play basketball. If 20% of students play both sports, what is the probability that a randomly selected student plays either football or basketball?

Answers:
1. 5/36
2. 1/6
3. 4/5

## Summary
- Probability trees are diagrams that represent the possible outcomes of a series of events.
- To construct a probability tree, identify the events and their possible outcomes, then label each branch with the probability of that outcome occurring.
- To calculate probabilities using probability trees, multiply the probabilities along each branch leading to the desired outcome and add the probabilities if there are multiple paths.
- The probability of events A and B occurring together is given by P(A and B) = P(A) × P(B|A).
- The probability of either event A or event B occurring is given by P(A or B) = P(A) + P(B) - P(A and B).

## Key Vocabulary/Formulas
| Term/Formula | Meaning/Use |
|--------------|-------------|
| Probability tree | A diagram that represents the possible outcomes of a series of events |
| Branch | A line in a probability tree that represents a possible outcome |
| P(A and B) = P(A) × P(B\|A) | The probability of events A and B occurring together |
| P(A or B) = P(A) + P(B) - P(A and B) | The probability of either event A or event B occurring |