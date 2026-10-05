import requests
from bs4 import BeautifulSoup


def decode_secret_message(url):
    """
    Fetches a published Google Doc containing a table of Unicode characters
    with their x and y coordinates, and prints the resulting grid to display
    a secret message made of uppercase letters.

    Args:
        url: String containing the URL of the published Google Doc.
    """
    # Fetch the document content
    response = requests.get(url)
    response.raise_for_status()

    # Parse the HTML to find the table
    soup = BeautifulSoup(response.text, 'html.parser')
    table = soup.find('table')

    if not table:
        print("No table found in the document.")
        return

    # Extract character positions from table rows (skip header row)
    rows = table.find_all('tr')
    characters = []

    for row in rows[1:]:  # Skip the header row
        cells = row.find_all('td')
        if len(cells) >= 3:
            x = int(cells[0].get_text().strip())
            char = cells[1].get_text().strip()
            y = int(cells[2].get_text().strip())
            characters.append((x, y, char))

    if not characters:
        print("No character data found in the table.")
        return

    # Determine grid dimensions
    max_x = max(c[0] for c in characters)
    max_y = max(c[1] for c in characters)

    # Create a grid filled with spaces
    grid = [[' ' for _ in range(max_x + 1)] for _ in range(max_y + 1)]

    # Place each character at its (x, y) position
    for x, y, char in characters:
        grid[y][x] = char

    # Print the grid from top (max_y) to bottom (0)
    # since (0, 0) is at the bottom-left corner
    for y_row in range(max_y, -1, -1):
        print(''.join(grid[y_row]))


# Test with the example document
if __name__ == "__main__":
    example_url = "https://docs.google.com/document/d/e/2PACX-1vTMOmshQe8YvaRXi6gEPKKlsC6UpFJSMAk4mQjLm_u1gmHdVVTaeh7nBNFBRlui0sTZ-snGwZM4DBCT/pub"
    decode_secret_message(example_url)
