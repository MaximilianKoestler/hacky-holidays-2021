#! /usr/bin/env python3

PREFIX = "SELECT * FROM articles where article_id = 100 AND UNICODE(SUBSTRING((SELECT TOP 1 ISNULL(CAST([value] AS NVARCHAR(4000)),CHAR(32)) FROM encryption_keys WHERE ISNULL(CAST([key] AS NVARCHAR(4000)),CHAR(32)) NOT IN (SELECT TOP 1 ISNULL(CAST([key] AS NVARCHAR(4000)),CHAR(32)) FROM encryption_keys ORDER BY [key]) ORDER BY [key]),"


def main():
    with open("traffic.sql") as traffic_file:
        lines = traffic_file.readlines()

    query_parts = []
    for i in range(len(lines)):
        line = lines[i]
        if line.startswith(PREFIX):
            part = line[len(PREFIX) :].strip() + "\t" + lines[i + 1].strip()
            print(i, part)
            query_parts.append(part)

    data = []
    for part in query_parts:
        # Format: "559 38,1))>64  409 138"
        offset = int(part.split(",")[0])
        back = part.split(">")[1]
        value = int(back.split("\t")[0])
        response_length = int(back.split("\t")[2])
        data.append((offset, value, response_length))

    result = {}
    for (offset, value, response_length) in data:
        result[offset] = (value, response_length)

    print(result)

    key = ""
    for (value, response_length) in result.values():
        if response_length == 200:
            value += 1
        key += chr(value)

    print(key)


if __name__ == "__main__":
    main()
