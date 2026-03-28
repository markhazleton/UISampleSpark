
namespace UISampleSpark.Core.Extensions;

public static class EnumerableExtensions
{
    public enum MinMaxOption
    {
        Minimum,
        Maximum,
        First,
        Last,
        Mean
    }

    public static T? SelectElementByOption<T, TKey>(this IEnumerable<T>? sequence, Func<T, TKey> keySelector, MinMaxOption option = MinMaxOption.Minimum)
        where T : class
        where TKey : IComparable<TKey>
    {
        ArgumentNullException.ThrowIfNull(keySelector);

        if (sequence == null || !sequence.Any())
            return default;

        switch (option)
        {
            case MinMaxOption.Minimum:
                return sequence
                    .Select(obj => Tuple.Create(obj, keySelector(obj)))
                    .Aggregate(default(Tuple<T, TKey>),
                        (best, cur) => best == null || cur.Item2.CompareTo(best.Item2) < 0 ? cur : best)!.Item1;

            case MinMaxOption.Maximum:
                return sequence
                    .Select(obj => Tuple.Create(obj, keySelector(obj)))
                    .Aggregate(default(Tuple<T, TKey>),
                        (best, cur) => best == null || cur.Item2.CompareTo(best.Item2) > 0 ? cur : best)!.Item1;

            case MinMaxOption.First:
                return sequence.FirstOrDefault();

            case MinMaxOption.Last:
                return sequence.LastOrDefault();

            case MinMaxOption.Mean:
                var candidates = sequence
                    .Select(element => (Element: element, Key: keySelector(element)))
                    .Where(static item => item.Key is IConvertible)
                    .Select(static item => (item.Element, NumericKey: Convert.ToDouble((IConvertible)item.Key)))
                    .ToList();

                if (candidates.Count == 0)
                    return default;

                double mean = candidates.Average(static item => item.NumericKey);
                return candidates
                    .OrderBy(item => Math.Abs(item.NumericKey - mean))
                    .Select(static item => item.Element)
                    .FirstOrDefault();

            default:
                return default;
        }
    }





}
