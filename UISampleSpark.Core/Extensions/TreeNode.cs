
namespace UISampleSpark.Core.Extensions;
/// <summary>
/// 
/// </summary>
/// <typeparam name="T"></typeparam>
public class TreeNode<T> where T : notnull, IComparable<T>
{
    public T Value { get; init; }
    private readonly List<TreeNode<T>> _children = new();
    public TreeNode(T value) => Value = value;
    public TreeNode<T> AddChild(T newChild)
    {
        int index = _children.FindIndex(x => x.Value.CompareTo(newChild) > 0);
        TreeNode<T> result = new TreeNode<T>(newChild);
        if (index < 0)
            _children.Add(result);
        else
            _children.Insert(index, result);
        return result;
    }
    public IEnumerable<(int Depth, T Value)> EnumerateSelfAndDescendantsWithDepth(int startDepth = 0)
    {
        yield return (startDepth, Value);
        ++startDepth;
        foreach (TreeNode<T> child in _children)
        {
            foreach ((int Depth, T Value) child2 in child.EnumerateSelfAndDescendantsWithDepth(startDepth))
                yield return child2;
        }
    }
    public IEnumerable<T> EnumerateSelfAndDescendants()
    {
        yield return Value;
        foreach (TreeNode<T> child in _children)
        {
            foreach (T child2 in child.EnumerateSelfAndDescendants())
                yield return child2;
        }
    }
}
