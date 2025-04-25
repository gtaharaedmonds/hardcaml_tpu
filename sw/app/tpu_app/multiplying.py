# Helper script to get some correct answers to larger matrices

import numpy as np

N = 8

if __name__ == "__main__":
    weight = np.array([[row * 8 + col for col in range(0, N)] for row in range(0, N)])
    data = np.array(
        [[64 + row * 8 + col for col in range(0, N)] for row in range(0, N)]
    )
    result = weight @ data

    print(weight)
    print(data)
    print(result)

    for row in result:
        inner = ", ".join(map(str, row))
        print(f"[{inner}],")
