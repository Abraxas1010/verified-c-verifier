#include <stdlib.h>
#include <stdint.h>
int sky_reducer_step(int* tags, int* lhs, int* rhs, int* oracleRefs, int* oracleValues, int* stack, int* focusPtr, int* stackSizePtr, int* nodeCountPtr, int maxNodes) {
  {
    int tag = 0;
    int focus = 0;
    int stackSize = 0;
    int nodeCount = 0;
    int x = 0;
    int y = 0;
    int z = 0;
    int ref = 0;
    focus = (*focusPtr);
    stackSize = (*stackSizePtr);
    nodeCount = (*nodeCountPtr);
    if ((focus < nodeCount)) {
      tag = tags[focus];
      if (tag == 0) {
        x = rhs[focus];
        (*(stack + stackSize)) = x;
        focus = lhs[focus];
        stackSize = (stackSize + 1);
        (*focusPtr) = focus;
        (*stackSizePtr) = stackSize;
        (*nodeCountPtr) = nodeCount;
        return 1;
      } else {
        if (tag == 1) {
          if ((stackSize >= 2)) {
            x = stack[(stackSize - 1)];
            focus = x;
            stackSize = (stackSize - 2);
            (*focusPtr) = focus;
            (*stackSizePtr) = stackSize;
            (*nodeCountPtr) = nodeCount;
            return 1;
          } else {
            (*focusPtr) = focus;
            (*stackSizePtr) = stackSize;
            (*nodeCountPtr) = nodeCount;
            return 0;
          }
        } else {
          if (tag == 2) {
            if ((stackSize >= 3)) {
              if (((nodeCount + 3) <= maxNodes)) {
                x = stack[(stackSize - 1)];
                y = stack[(stackSize - 2)];
                z = stack[(stackSize - 3)];
                (*(tags + (nodeCount + 0))) = 0;
                (*(lhs + (nodeCount + 0))) = x;
                (*(rhs + (nodeCount + 0))) = z;
                (*(oracleRefs + (nodeCount + 0))) = 0;
                (*(tags + (nodeCount + 1))) = 0;
                (*(lhs + (nodeCount + 1))) = y;
                (*(rhs + (nodeCount + 1))) = z;
                (*(oracleRefs + (nodeCount + 1))) = 0;
                (*(tags + (nodeCount + 2))) = 0;
                (*(lhs + (nodeCount + 2))) = (nodeCount + 0);
                (*(rhs + (nodeCount + 2))) = (nodeCount + 1);
                (*(oracleRefs + (nodeCount + 2))) = 0;
                focus = (nodeCount + 2);
                nodeCount = (nodeCount + 3);
                stackSize = (stackSize - 3);
                (*focusPtr) = focus;
                (*stackSizePtr) = stackSize;
                (*nodeCountPtr) = nodeCount;
                return 1;
              } else {
                (*focusPtr) = focus;
                (*stackSizePtr) = stackSize;
                (*nodeCountPtr) = nodeCount;
                return 2;
              }
            } else {
              (*focusPtr) = focus;
              (*stackSizePtr) = stackSize;
              (*nodeCountPtr) = nodeCount;
              return 0;
            }
          } else {
            if (tag == 3) {
              if ((stackSize >= 1)) {
                if (((nodeCount + 2) <= maxNodes)) {
                  x = stack[(stackSize - 1)];
                  (*(tags + (nodeCount + 0))) = 0;
                  (*(lhs + (nodeCount + 0))) = focus;
                  (*(rhs + (nodeCount + 0))) = x;
                  (*(oracleRefs + (nodeCount + 0))) = 0;
                  (*(tags + (nodeCount + 1))) = 0;
                  (*(lhs + (nodeCount + 1))) = x;
                  (*(rhs + (nodeCount + 1))) = (nodeCount + 0);
                  (*(oracleRefs + (nodeCount + 1))) = 0;
                  focus = (nodeCount + 1);
                  nodeCount = (nodeCount + 2);
                  stackSize = (stackSize - 1);
                  (*focusPtr) = focus;
                  (*stackSizePtr) = stackSize;
                  (*nodeCountPtr) = nodeCount;
                  return 1;
                } else {
                  (*focusPtr) = focus;
                  (*stackSizePtr) = stackSize;
                  (*nodeCountPtr) = nodeCount;
                  return 2;
                }
              } else {
                (*focusPtr) = focus;
                (*stackSizePtr) = stackSize;
                (*nodeCountPtr) = nodeCount;
                return 0;
              }
            } else {
              if (tag == 4) {
                if ((stackSize >= 2)) {
                  x = stack[(stackSize - 1)];
                  y = stack[(stackSize - 2)];
                  ref = oracleRefs[focus];
                  if ((oracleValues[ref] != 0)) {
                    focus = x;
                    stackSize = (stackSize - 2);
                    (*focusPtr) = focus;
                    (*stackSizePtr) = stackSize;
                    (*nodeCountPtr) = nodeCount;
                    return 1;
                  } else {
                    focus = y;
                    stackSize = (stackSize - 2);
                    (*focusPtr) = focus;
                    (*stackSizePtr) = stackSize;
                    (*nodeCountPtr) = nodeCount;
                    return 1;
                  }
                } else {
                  (*focusPtr) = focus;
                  (*stackSizePtr) = stackSize;
                  (*nodeCountPtr) = nodeCount;
                  return 0;
                }
              } else {
                (*focusPtr) = focus;
                (*stackSizePtr) = stackSize;
                (*nodeCountPtr) = nodeCount;
                return 0;
              }
            }
          }
        }
      }
    } else {
      (*focusPtr) = focus;
      (*stackSizePtr) = stackSize;
      (*nodeCountPtr) = nodeCount;
      return 0;
    }
  }
}
