# peanut-butter

Factoring factorials equitably

Welcome to the Peanut Butter project! Our mission is to implement the algorithms described in Terence Tao's blog post on [Decomposing a Factorial into Large Factors](https://terrytao.wordpress.com/2025/03/26/decomposing-a-factorial-into-large-factors/). Imagine spreading peanut butter on a slice of bread; our goal is to spread it as evenly as possible, just as Terry Tao has asked us to spread the factors of a factorial as evenly as possible.

## Project Overview

This repository focuses on the equitable factorization of factorials, inspired by the work of Erdös and further explored by Terence Tao. We aim to implement various algorithms to achieve this goal.

## Current Implementations

We have multiple implementations of the "simple construction by Guy and Selfridge" mentioned in Tao's blog post. These implementations explore different data structures and their performance. We can benchmark the performance using the `benchmark.zig` file. This may help us choose the optimal data structure pattern that scales to larger input sizes before tackling the more complex algorithms.

## Future Work

We have not yet implemented the more complicated constructions that Tao has requested involving starting from a large odd composite number B that approximates N!. That is a more challenging task but we hope it may include similar operations or data structures to the simpler redistribution algorithm.

## Getting Started

To get started with the project, clone the repository and explore the existing implementations. Feel free to contribute by experimenting with new data structures or optimizing the current algorithms. The code is writtne in [Zig](https://ziglang.org/) since it enables writing low-level performant code which might be important for the large data sizes we will process but has some nice features that C lacks.
## Contributing

We welcome contributions! If you have ideas for improving the algorithms or implementing the more complex constructions, please open a pull request. If you are interested but don't know where to start, our [issues](https://github.com/anandsun/peanut-butter/issues) track some ideas that could be good starting points. 

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Acknowledgments

Special thanks to Terence Tao for challenging those of us "who are adept with computers" to experiment with these concepts. Let's see how evenly we can spread the peanut butter!
