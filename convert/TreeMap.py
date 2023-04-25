class Map:
    """A map (dictionary) represented as a binary search tree."""

    def __init__(self, key=None, val=None, left=None, right=None):
        if key is None:
            # empty map
            self.key = None
            self.val = None
            self.left = None
            self.right = None
        else:
            self.key = key
            self.val = val
            self.left = left
            self.right = right

    def is_empty(self) -> bool:
        return (self.key is None)

    def is_leaf(self) -> bool:
        return ((self.key is not None) and
                (self.left is None or self.left.is_empty()) and
                (self.right is None or self.right.is_empty()))

    def get_left(self):
        return self.left if self.left else Map()

    def get_right(self):
        return self.right if self.right else Map()

    def __str__(self):
        if self.is_empty():
            return "Map()"
        elif self.is_leaf():
            return "Map({0},{1})".format(self.key, self.val)
        else:
            return f"Map({self.key},{self.val},{self.left},{self.right})"

    def to_json(self):
        """The map in JSON format."""
        if self.is_empty():
            return []
        elif self.is_leaf():
            return [[self.val, self.key]]
        else:
            return [self.key, self.val, self.get_left.to_json(), self.get_right.to_json]
