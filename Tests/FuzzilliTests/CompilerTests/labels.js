L1: {
    L2: {
        console.log("a");
        {
            console.log("b")
        }
        L3: {
            console.log("c");
            break L1;
            break L2;
        }
        console.log("d");
        break L1;
    }
    console.log("e");
    break L1;
}

L4: {
    L5: {
        L6: {
            console.log("0");
            L7: {
                break L5;
            }
            console.log("1");
            break L4;
        }
    }
}
console.log("2");
