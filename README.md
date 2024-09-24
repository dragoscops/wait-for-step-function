# wait-for-step-function

![GitHub Actions](https://img.shields.io/github/actions/workflow/status/your-username/your-repo/wait-for-step-function.yml?branch=main&label=GitHub%20Actions)
![License](https://img.shields.io/github/license/your-username/your-repo)

- [wait-for-step-function](#wait-for-step-function)
  - [Table of Contents](#table-of-contents)
  - [Description](#description)
  - [Features](#features)
  - [Prerequisites](#prerequisites)
  - [⚙️ Inputs](#️-inputs)
    - [Input Details](#input-details)
  - [Usage](#usage)
    - [Basic Example](#basic-example)
    - [Advanced Example with Custom Timeout and Wait Interval](#advanced-example-with-custom-timeout-and-wait-interval)
    - [Explanation](#explanation)
  - [Repository Structure](#repository-structure)


## Table of Contents

- [wait-for-step-function](#wait-for-step-function)
  - [Table of Contents](#table-of-contents)
  - [Description](#description)
  - [Features](#features)
  - [Prerequisites](#prerequisites)
  - [⚙️ Inputs](#️-inputs)
    - [Input Details](#input-details)
  - [Usage](#usage)
    - [Basic Example](#basic-example)
    - [Advanced Example with Custom Timeout and Wait Interval](#advanced-example-with-custom-timeout-and-wait-interval)
    - [Explanation](#explanation)
  - [Repository Structure](#repository-structure)

## Description

**`wait-for-step-function`** is a GitHub Action designed to monitor AWS Step Function executions based on specified filter criteria. It continuously polls the status of a Step Function execution, waiting for it to complete successfully, fail, timeout, or be aborted. This action is particularly useful in CI/CD pipelines where subsequent steps depend on the successful completion of a Step Function.

## Features

- **Dynamic Filtering:** Allows specifying multiple key-value pairs to filter and identify the correct Step Function execution.
- **Configurable Timeout:** Set a maximum wait time to prevent indefinite waiting.
- **Custom Polling Interval:** Define how frequently the action checks the status of the Step Function.
- **Comprehensive Logging:** Provides detailed logs for monitoring and debugging.
- **Flexible Integration:** Easily integrates into existing GitHub workflows.

## Prerequisites

Before using this action, ensure you have the following:

1. **AWS Account:** Access to AWS Step Functions with the necessary permissions.
2. **AWS CLI Configuration:** The GitHub Actions runner must have AWS credentials configured with permissions to interact with Step Functions.
3. **jq Installed:** Although the action installs `jq`, ensure that your environment allows the installation of additional packages.

## ⚙️ Inputs

| Input          | Description                                                                                  | Required | Default |
|----------------|----------------------------------------------------------------------------------------------|----------|---------|
| `name`         | **(Required)** Name of the AWS Step Function state machine to monitor.                       | Yes      | N/A     |
| `filter`       | **(Required)** JSON object containing key-value pairs to filter Step Function executions.     | Yes      | N/A     |
| `timeout`      | Timeout in seconds to wait for the Step Function to complete. Default is `3600` seconds (1 hour). | No       | `3600`  |
| `wait_interval`| Interval in seconds between each poll to check the Step Function status. Default is `15` seconds. | No       | `15`    |

### Input Details

- **`name`**: The exact name of the Step Function state machine you want to monitor.
  
- **`filter`**: A JSON-formatted string containing the filters to identify the specific execution. For example:
  
  ```json
  {
    "subdomain": "example.com",
    "email": "user@example.com"
  }
  ```
  
- **`timeout`**: Maximum time the action will wait for the Step Function execution to complete before failing.
  
- **`wait_interval`**: Frequency at which the action polls the Step Function execution status.

## Usage

Integrate the **`wait-for-step-function`** action into your GitHub workflow to monitor AWS Step Function executions effectively.

### Basic Example

```yaml
name: Monitor AWS Step Function

on:
  push:
    branches:
      - main

jobs:
  monitor_step_function:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3

      - name: Wait for Step Function Execution
        uses: your-username/your-repo@v1.0.0
        with:
          name: "MyStateMachine"
          filter: '{"subdomain": "example.com", "email": "user@example.com"}'
```

### Advanced Example with Custom Timeout and Wait Interval

```yaml
name: Monitor AWS Step Function with Custom Settings

on:
  workflow_dispatch:

jobs:
  monitor_step_function:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3

      - name: Wait for Step Function Execution
        uses: your-username/your-repo@v1.0.0
        with:
          name: "MyStateMachine"
          filter: '{"subdomain": "example.com", "email": "user@example.com"}'
          timeout: 7200            # Wait up to 2 hours
          wait_interval: 30        # Poll every 30 seconds
```

### Explanation

1. **Checkout Repository:**
   - Uses the `actions/checkout` action to clone your repository onto the runner.
   
2. **Wait for Step Function Execution:**
   - Utilizes the `wait-for-step-function` action.
   - **`name`**: Specifies the Step Function state machine to monitor.
   - **`filter`**: Provides the JSON object to filter executions.
   - **`timeout`** *(Optional)*: Sets a custom timeout value.
   - **`wait_interval`** *(Optional)*: Sets a custom polling interval.

## Repository Structure

Ensure your repository has the following structure to support the action:

```
your-repo/
├── action.yml
├── wait-for-step-function.sh
└── lib/
    └── logging.sh
```

- **`action.yml`**: Defines the GitHub Action, its inputs, and the steps to execute.
- **`wait-for-step-function.sh`**: The main script that performs the monitoring of the Step Function execution.
- **`lib/logging.sh`**: A logging library script used for structured and leveled logging within your main script.