#!/bin/bash
watch -n1 'nvidia-smi --query-gpu=index,name,temperature.gpu,power.draw,utilization.gpu,memory.used,pcie.link.gen.current,pcie.link.width.current --format=csv'
